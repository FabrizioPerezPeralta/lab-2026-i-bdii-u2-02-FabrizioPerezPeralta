FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build-env
WORKDIR /app

# Copy everything
COPY BooksApi/ ./BooksApi/
WORKDIR /app/BooksApi
RUN dotnet restore
RUN dotnet publish -c Release -o out

# Build runtime image
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build-env /app/BooksApi/out .
ENTRYPOINT ["dotnet", "BooksApi.dll"]
