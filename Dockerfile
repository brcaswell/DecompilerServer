FROM mcr.microsoft.com/dotnet/runtime:8.0 AS base
WORKDIR /app

USER app
FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:8.0 AS build
ARG configuration=Release
WORKDIR /src
COPY ["DecompilerServer.csproj", "./"]
RUN dotnet restore "DecompilerServer.csproj"
COPY . .
WORKDIR "/src/."
RUN dotnet build "DecompilerServer.csproj" -c $configuration -o /app/build

FROM build AS publish
ARG configuration=Release
RUN dotnet publish "DecompilerServer.csproj" -c $configuration -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .

# Environment variable to control verbose logging
ENV DECOMPILER_VERBOSE=false

# Use shell form to support environment variable expansion
ENTRYPOINT ["/bin/sh", "-c", "if [ \"$DECOMPILER_VERBOSE\" = \"true\" ]; then dotnet DecompilerServer.dll --verbose; else dotnet DecompilerServer.dll; fi"]
