      $inputJson = [Console]::In.ReadToEnd()
      $data = $inputJson | ConvertFrom-Json
      $params = $data.resource_params

      $certPath = if ($params.path) { $params.path } else { (Join-Path -Path $env:USERPROFILE -ChildPath "certs/aspnet.pfx")} #"C:/certs/aspnet.pfx"}
      $certFolder = Split-Path -Path $certPath -Parent
      $certName = Split-Path -Path $certPath -Leaf
      $password = if ($params.password) { $params.password } else { "password" }

      if (-not (Test-Path $certFolder)) {
          New-Item -ItemType Directory -Path $certFolder | Out-Null
      }

      if (-not (Test-Path $certPath)) {
          $args = @(
                'dev-certs'
                'https'
                '-ep'; $certPath
                '-p'; $password
            )
          & dotnet @args | Out-Null
      }

      $output = @{
        resource_outputs =  @{
            password = $password
            sourcePath = $certPath
            name = $certName
        }
      }

      $outputJson = $output | ConvertTo-Json
      [Console]::Out.Write($outputJson)