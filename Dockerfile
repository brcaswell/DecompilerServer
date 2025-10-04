FROM mcr.microsoft.com/dotnet/runtime:8.0-alpine AS base
WORKDIR /app
# Use existing app user and ensure proper permissions
RUN chown -R app:app /app
USER app

FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build
ARG configuration=Release
WORKDIR /src

# Copy project file and restore dependencies
COPY ["DecompilerServer.csproj", "./"]
RUN dotnet restore "DecompilerServer.csproj" -r linux-musl-x64

# Copy source code
COPY . .

# Build the application
RUN dotnet build "DecompilerServer.csproj" -c $configuration -o /app/build --no-restore

FROM build AS publish
ARG configuration=Release
# Publish with optimizations: trimming, single file, no debug symbols
RUN dotnet publish "DecompilerServer.csproj" \
    -c $configuration \
    -o /app/publish \
    --no-restore \
    -r linux-musl-x64 \
    --self-contained false \
    /p:UseAppHost=false \
    /p:PublishTrimmed=true \
    /p:TrimMode=partial \
    /p:PublishSingleFile=false \
    /p:DebugType=none \
    /p:DebugSymbols=false

FROM base AS final
WORKDIR /app

# Copy the published application
COPY --from=publish --chown=app:app /app/publish .

# Environment variable to control verbose logging
ENV DECOMPILER_VERBOSE=false

# Use exec form for better signal handling
ENTRYPOINT ["sh", "-c", "if [ \"$DECOMPILER_VERBOSE\" = \"true\" ]; then dotnet DecompilerServer.dll --verbose; else dotnet DecompilerServer.dll; fi"]
