#!/bin/sh
set -e

if [ -d "/init-scripts" ]; then
  for script in /init-scripts/*.sh; do
    if [ -x "$script" ]; then
      echo "Ejecutando $script..."
      "$script"
    else
      echo "Saltando $script (no es ejecutable)"
    fi
  done
fi

tail -f /dev/null
#dotnet --roll-forward Major /VSTools/DistrolessHelper/DistrolessHelper.dll --wait
