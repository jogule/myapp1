# Use the official .NET SDK image for building
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy solution file and project files
COPY myapp1.sln ./
COPY myapp1/myapp1.csproj ./myapp1/
COPY myapp1.E2ETests/myapp1.E2ETests.csproj ./myapp1.E2ETests/

# Restore dependencies
RUN dotnet restore myapp1.sln

# Copy the rest of the source code
COPY . .

# Build the application
RUN dotnet build myapp1/myapp1.csproj -c Release -o /app/build

# Publish the application
RUN dotnet publish myapp1/myapp1.csproj -c Release -o /app/publish --no-restore

# Use the official .NET runtime image for the final stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Copy the published application from the build stage
COPY --from=build /app/publish .

# Expose the port the app runs on
EXPOSE 8080

# Set environment variables
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production

# Create a non-root user
RUN adduser --disabled-password --home /app --gecos '' appuser && chown -R appuser /app
USER appuser

# Set the entry point
ENTRYPOINT ["dotnet", "myapp1.dll"]
