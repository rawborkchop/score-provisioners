FROM mcr.microsoft.com/dotnet/sdk:{{DOTNET_VERSION}} AS build
WORKDIR /src
COPY . .
