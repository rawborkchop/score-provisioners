using System;
using System.Configuration;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.IO;
using System.Linq;
using System.Reflection;

namespace EnvConfigLoader
{
    public static class EnvConfigLoader
    {
        /// <summary>
        /// Carga variables desde un fichero .env y las inyecta en ConfigurationManager
        /// sólo si comienzan por el prefijo indicado.
        /// </summary>
        /// <param name="envFilePath">Ruta al .env</param>
        /// <param name="prefixFilter">Prefijo a filtrar (p.ej. "MYAPP_")</param>
        public static void LoadEnvFile(string envFilePath, string prefixFilter)
        {
            if (!File.Exists(envFilePath))
                throw new FileNotFoundException($"No se encontró el fichero de entorno: {envFilePath}");

            var variables = File.ReadAllLines(envFilePath)
                .Select(line => line.Trim())
                .Where(line =>
                    !string.IsNullOrEmpty(line) &&
                    !line.StartsWith("#") &&
                    line.Contains('='))
                .Select(line =>
                {
                    var idx = line.IndexOf('=');
                    var key = line.Substring(0, idx).Trim();
                    var val = line.Substring(idx + 1).Trim().Trim('"');
                    return new { Key = key, Value = val };
                })
                .Where(kv => kv.Key.StartsWith(prefixFilter, StringComparison.OrdinalIgnoreCase))
                .ToDictionary(kv => kv.Key, kv => kv.Value);

            ApplyVariablesInMemory(variables);
        }

        /// <summary>
        /// Lee variables de entorno del sistema y las inyecta en ConfigurationManager
        /// sólo si comienzan por el prefijo indicado.
        /// </summary>
        /// <param name="prefixFilter">Prefijo a filtrar (p.ej. "MYAPP_")</param>
        public static void LoadFromEnvironment(string? prefixFilter)
        {
            var allEnv = Environment.GetEnvironmentVariables();
            var variables = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

            foreach (DictionaryEntry de in allEnv)
            {
                var rawKey = de.Key.ToString();
                if (!rawKey.StartsWith(prefixFilter, StringComparison.OrdinalIgnoreCase))
                    continue;

                variables[rawKey.Replace(prefixFilter + "_", "")] = de.Value?.ToString() ?? string.Empty;
            }

            ApplyVariablesInMemory(variables);
        }

        private static void ApplyVariablesInMemory(Dictionary<string, string> variables)
        {
            const string csPrefix = "ConnectionStrings__";

            var connStringSettings = ConfigurationManager.ConnectionStrings;
            var readonlyField = typeof(ConfigurationElementCollection)
                .GetField("bReadOnly", BindingFlags.Instance | BindingFlags.NonPublic);
            readonlyField?.SetValue(connStringSettings, false);

            foreach (var kv in variables)
            {
                var key = kv.Key;
                var value = kv.Value;

                if (key.StartsWith(csPrefix, StringComparison.OrdinalIgnoreCase))
                {
                    var csName = key.Substring(csPrefix.Length);
                    SetConnectionString(csName, value, connStringSettings);
                    continue;
                }

                var parts = key.Split(new[] { "__" }, 2, StringSplitOptions.None);
                if (parts.Length == 2)
                {
                    var sectionName = parts[0];
                    var settingKey = parts[1];

                    var section = ConfigurationManager.GetSection(sectionName) as NameValueCollection;
                    if (section != null)
                    {
                        section[settingKey] = value;
                        continue;
                    }
                }

                ConfigurationManager.AppSettings[key] = value;
            }

            readonlyField?.SetValue(connStringSettings, true);
        }

        private static void SetConnectionString(
            string name,
            string connectionString,
            ConnectionStringSettingsCollection connStrings)
        {
            var existing = connStrings[name];
            if (existing != null)
            {
                existing.ConnectionString = connectionString;
            }
            else
            {
                connStrings.Add(new ConnectionStringSettings(name, connectionString));
            }
        }
    }
}
