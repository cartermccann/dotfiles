/* Exercise fresh Secret Service clients on the private bus supplied by check.py. */
#include <gio/gio.h>
#include <stdio.h>
#include <string.h>

static gint failures;
static const char *algorithm;

static GDBusConnection *connect_bus(GError **error) {
    return g_dbus_connection_new_for_address_sync(
        g_getenv("DBUS_SESSION_BUS_ADDRESS"),
        G_DBUS_CONNECTION_FLAGS_AUTHENTICATION_CLIENT |
            G_DBUS_CONNECTION_FLAGS_MESSAGE_BUS_CONNECTION,
        NULL, NULL, error);
}

static gpointer worker(gpointer unused) {
    (void)unused;
    for (int i = 0; i < 200; i++) {
        GError *error = NULL;
        GDBusConnection *connection = connect_bus(&error);
        GVariant *reply = NULL;
        if (connection) {
            guint8 public_key[128] = {0};
            public_key[127] = 2; /* Valid group element; no stored credentials. */
            gboolean aes = strcmp(algorithm, "dh-ietf1024-sha256-aes128-cbc-pkcs7") == 0;
            GVariant *input = aes
                ? g_variant_new_fixed_array(G_VARIANT_TYPE_BYTE, public_key, 128, 1)
                : g_variant_new_string("");
            reply = g_dbus_connection_call_sync(
                connection, "org.freedesktop.secrets", "/org/freedesktop/secrets",
                "org.freedesktop.Secret.Service", "OpenSession",
                g_variant_new("(sv)", algorithm, input), G_VARIANT_TYPE("(vo)"),
                G_DBUS_CALL_FLAGS_NO_AUTO_START, 3000, NULL, &error);
            if (reply) {
                GVariant *output;
                const char *path;
                g_variant_get(reply, "(v&o)", &output, &path);
                if (!g_variant_is_of_type(output, aes ? G_VARIANT_TYPE("ay") : G_VARIANT_TYPE_STRING) ||
                    !g_str_has_prefix(path, "/org/freedesktop/secrets/session/"))
                    g_atomic_int_inc(&failures);
                GVariant *closed = g_dbus_connection_call_sync(
                    connection, "org.freedesktop.secrets", path,
                    "org.freedesktop.Secret.Session", "Close", NULL,
                    G_VARIANT_TYPE_UNIT, G_DBUS_CALL_FLAGS_NO_AUTO_START,
                    3000, NULL, &error);
                if (!closed) g_atomic_int_inc(&failures);
                if (closed) g_variant_unref(closed);
                g_variant_unref(output);
                g_variant_unref(reply);
            } else {
                g_atomic_int_inc(&failures);
            }
            g_dbus_connection_close_sync(connection, NULL, NULL);
            g_object_unref(connection);
        } else {
            g_atomic_int_inc(&failures);
        }
        g_clear_error(&error);
    }
    return NULL;
}

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    algorithm = argv[1];
    if (!strcmp(algorithm, "owner") || !strcmp(algorithm, "invalid") ||
        !strcmp(algorithm, "invalid-type")) {
        GError *error = NULL;
        GDBusConnection *connection = connect_bus(&error);
        if (!connection) { g_clear_error(&error); return 1; }
        gboolean owner = !strcmp(algorithm, "owner");
        gboolean invalid_type = !strcmp(algorithm, "invalid-type");
        GVariant *reply = owner ? g_dbus_connection_call_sync(
            connection, "org.freedesktop.DBus", "/org/freedesktop/DBus",
            "org.freedesktop.DBus", "GetConnectionUnixProcessID",
            g_variant_new("(s)", "org.freedesktop.secrets"), G_VARIANT_TYPE("(u)"),
            G_DBUS_CALL_FLAGS_NO_AUTO_START, 1000, NULL, &error)
            : g_dbus_connection_call_sync(
                connection, "org.freedesktop.secrets", "/org/freedesktop/secrets",
                "org.freedesktop.Secret.Service", "OpenSession",
                g_variant_new("(sv)", invalid_type ? "dh-ietf1024-sha256-aes128-cbc-pkcs7"
                                                   : "not-an-algorithm", g_variant_new_string("")),
                G_VARIANT_TYPE("(vo)"), G_DBUS_CALL_FLAGS_NO_AUTO_START, 3000, NULL, &error);
        int result = 1;
        if (owner && reply) {
            guint32 pid;
            g_variant_get(reply, "(u)", &pid);
            printf("%u\n", pid);
            result = 0;
        } else if (!owner && error && g_dbus_error_is_remote_error(error)) {
            char *name = g_dbus_error_get_remote_error(error);
            result = strcmp(name, invalid_type ? "org.freedesktop.DBus.Error.InvalidArgs"
                                              : "org.freedesktop.DBus.Error.NotSupported") != 0;
            g_free(name);
        }
        if (reply) g_variant_unref(reply);
        g_clear_error(&error);
        g_dbus_connection_close_sync(connection, NULL, NULL);
        g_object_unref(connection);
        return result;
    }
    GThread *threads[16];
    for (int i = 0; i < 16; i++) threads[i] = g_thread_new("client", worker, NULL);
    for (int i = 0; i < 16; i++) g_thread_join(threads[i]);
    printf("%s: 3200 fresh connections, %d failures\n", algorithm, failures);
    return failures ? 1 : 0;
}
