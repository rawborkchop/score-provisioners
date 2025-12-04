FROM mcr.microsoft.com/dotnet/sdk:{{DOTNET_VERSION}} AS build
WORKDIR /src
COPY . .
RUN dotnet restore
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish --no-restore -c $BUILD_CONFIGURATION -o /app/publish
