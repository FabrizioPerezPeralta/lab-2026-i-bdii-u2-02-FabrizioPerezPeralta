[![Review Assignment Due Date](https://classroom.github.com/assets/deadline-readme-button-22041afd0340ce965d47ae6ef1cefeee28c7c493a6346c4f15d667ab976d596c.svg)](https://classroom.github.com/a/y9my6d6A)
[![Open in Codespaces](https://classroom.github.com/assets/launch-codespace-2972f46106e565e64193e422d61a12cf1da4916b45550586e14ef0a7c637dd04.svg)](https://classroom.github.com/open-in-codespaces?assignment_repo_id=24135359)
# SESION DE LABORATORIO N° 02: Generando un API utilizando una Base de Datos Documental (MongoDB)

### Nombre: Fabrizio Salvador Elias Perez Peralta

## OBJETIVOS
  * Comprender el funcionamiento de un motor de base de datos no relacional del tipo documental a través de su despliegue y uso.

## REQUERIMIENTOS
  * Conocimientos: 
    - Conocimientos básicos de gestión de base de datos de documentos
    - Conocimientos básicos de shell (linea de comandos).
  * Hardware:
    - Virtualization activada en el BIOS..
    - CPU SLAT-capable feature.
    - Al menos 4GB de RAM.
  * Software:
    - Windows 10 64bit: Pro, Enterprise o Education (1607 Anniversary Update, Build 14393 o Superior)
    - Docker Desktop 
    - Powershell versión 7.x
    - .Net 6 o superior

## CONSIDERACIONES INICIALES
  * Clonar el repositorio mediante git para tener los recursos necesaarios

## DESARROLLO

### PARTE I: Configuración de la base de datos

1. Iniciar la aplicación Docker Desktop:
2. Iniciar la aplicación Powershell o Windows Terminal en modo administrador 
3. Ejecutar el siguiente comando para iniciar una nueva instancia de una base de datos Mongo
```
docker run --name mongodb -d -p 27017:27017 mongo
```
4. Verificar sus ejecución y nombre con el siguiente comando. 
```
docker ps
```
deberá visualizar algo similar a:
```
CONTAINER ID   IMAGE     COMMAND                  CREATED              STATUS              PORTS                      NAMES
f293cca76b24   mongo     "docker-entrypoint.s…"   About a minute ago   Up About a minute   0.0.0.0:27017->27017/tcp   mongodb
```
5. Conectarse al gestor de base de datos mediante el siguiente comando:
```
docker exec -it mongodb mongosh
```
6. Crear la base de datos BookstoreDB, con el siguiente comando:
```
use BookstoreDb
```
7. Crear la colección Books, dentro de la base de datos:
```
db.createCollection('Books')
```
8. Insertar algunos datos de pruebas en la colección Books:
```
db.Books.insertMany([{'Name':'Design Patterns','Price':54.93,'Category':'Computers','Author':'Ralph Johnson'}, {'Name':'Clean Code','Price':43.15,'Category':'Computers','Author':'Robert C. Martin'}])
```
9. Verificar los datos ingresados mediante el siguiente comando:
```
db.Books.find({}).pretty()
```

### PARTE II: Creación del API

1. Iniciar la aplicación Powershell o Windows Terminal en modo administrador si es que no se tiene iniciada y ejecutar el siguiente comando:
```
dotnet new webapi -o BooksApi
```
2. Acceder a la carpeta recien creada y adicionar la libreria de Mongo para Net.
```
cd ./BooksApi/
dotnet add package MongoDB.Driver
```
3. Iniciar Visual Studio Code tomando como base la carpeta generada (BooksApi). Dentro del proyecto añadir el archivo Book.cs el cual tendrña la clase entidad, con el siguiente código
```C#
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace BooksApi.Models
{
    public class Book
    {
        [BsonId]
        [BsonRepresentation(BsonType.ObjectId)]
        public string Id { get; set; }
        [BsonElement("Name")]
        public string BookName { get; set; }
        public decimal Price { get; set; }
        public string Category { get; set; }
        public string Author { get; set; }
    }
}
```
5. Ahora proceder a añadir la clase de configuración con el nombre de archivo BookStoreDatabaseSettings.cs e introducir el siguiente código:
```C#
namespace BooksApi.Models
{
    public class BookStoreDatabaseSettings
    {
        public string BooksCollectionName { get; set; }
        public string ConnectionString { get; set; }
        public string DatabaseName { get; set; }
    }
}
```
4. Modificar el archivo appsettings.json para que apunte a la base de datos local de datos, añadir:
```JSON
  "BookStoreDatabase": {
    "ConnectionString": "mongodb://127.0.0.1:27017",
    "DatabaseName": "BookstoreDb",
    "BooksCollectionName": "Books"
  },
```
5. Crear el archivo BookService.cs con el siguiente código:
```C#
using BooksApi.Models;
using Microsoft.Extensions.Options;
using MongoDB.Driver;

namespace BooksApi.Services;

public class BookService
{
    private readonly IMongoCollection<Book> _booksCollection;

    public BookService(
        IOptions<BookStoreDatabaseSettings> bookStoreDatabaseSettings)
    {
        var mongoClient = new MongoClient(
            bookStoreDatabaseSettings.Value.ConnectionString);

        var mongoDatabase = mongoClient.GetDatabase(
            bookStoreDatabaseSettings.Value.DatabaseName);

        _booksCollection = mongoDatabase.GetCollection<Book>(
            bookStoreDatabaseSettings.Value.BooksCollectionName);
    }

    public async Task<List<Book>> GetAsync() =>
        await _booksCollection.Find(_ => true).ToListAsync();

    public async Task<Book?> GetAsync(string id) =>
        await _booksCollection.Find(x => x.Id == id).FirstOrDefaultAsync();

    public async Task CreateAsync(Book newBook) =>
        await _booksCollection.InsertOneAsync(newBook);

    public async Task UpdateAsync(string id, Book updatedBook) =>
        await _booksCollection.ReplaceOneAsync(x => x.Id == id, updatedBook);

    public async Task RemoveAsync(string id) =>
        await _booksCollection.DeleteOneAsync(x => x.Id == id);
}
```
6. En el archivo Program.cs adicionar el siguiente código.
```C#
//Al inicio
using BooksApi.Models;
using BooksApi.Services;
...
// Add services to the container.
builder.Services.Configure<BookStoreDatabaseSettings>(builder.Configuration.GetSection("BookStoreDatabase"));
builder.Services.AddSingleton<BookService>();
```
7. Adicionalmente crear el archivo BooksController.cs en la carpeta Controllers con el siguiente código:
```C#
using BooksApi.Models;
using BooksApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace BookStoreApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class BooksController : ControllerBase
{
    private readonly BookService _booksService;

    public BooksController(BookService booksService) =>
        _booksService = booksService;

    [HttpGet]
    public async Task<List<Book>> Get() {
        return await _booksService.GetAsync();
    }
    
    [HttpGet("{id:length(24)}")]
    public async Task<ActionResult<Book>> Get(string id)
    {
        var book = await _booksService.GetAsync(id);
        if (book is null) return NotFound();
        return book;
    }

    [HttpPost]
    public async Task<IActionResult> Post(Book newBook)
    {
        await _booksService.CreateAsync(newBook);
        return CreatedAtAction(nameof(Get), new { id = newBook.Id }, newBook);
    }

    [HttpPut("{id:length(24)}")]
    public async Task<IActionResult> Update(string id, Book updatedBook)
    {
        var book = await _booksService.GetAsync(id);

        if (book is null) return NotFound();
        updatedBook.Id = book.Id;
        await _booksService.UpdateAsync(id, updatedBook);
        return NoContent();
    }

    [HttpDelete("{id:length(24)}")]
    public async Task<IActionResult> Delete(string id)
    {
        var book = await _booksService.GetAsync(id);
        if (book is null) return NotFound();
        await _booksService.RemoveAsync(id);
        return NoContent();
    }
}
```
8. Iniciar un terminal en VS Code (CTRL+Ñ) o volver al terminal anteriomente abierto y ejecutar la aplicación con el comando:
```
dotnet run
```
9. Iniciar un navegador de internet e introducir la url http://localhost:XXXXX/swagger (donde XXXXX es el puerto donde esta eejcutandose la aplicación), una vez cargada la interfaz de Swagger, en el metodo Create, ingresar los siguientes datos y probar:
```JSON
{
  "id":"61a6058e6c43f32854e51f52",
  "bookName":"Clean Code",
  "price":43.15,
  "category":"Computers",
  "author":"Robert C. Martin"
}
```

---
## Actividades Encargadas
1. Genere el archivo Dockerfile para dockerizar el API creado.
2. Genere el archivo main.tf dentro de la carpeta infra, para crear mediante Terraform la infrastructura, en MongoDb Atlas (https://www.mongodb.com/products/platform/atlas-database) y el backend en un servicio Azure AppService u otro servicio Saas que maneje contenedores
3. Genere la automatizacion infra.yml, que despliegue la infraestrutura.
4. Genere la automatización deploydb.yml, que permita cargar datos en su base de datos MongoDB.
5. Genere la automatizacion buildimage.yml para construir la imagen y publicarla como paquete en su repositorio.
6. Genere la automatizacion deployimage.yml que despliege la imagen previamente publicada en el servicio Web que maneje contenedores.
