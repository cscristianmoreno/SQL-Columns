***SQL Columns***

**SQL Columns** es un proyecto que interactúa con una base de datos a través del lenguaje **Pawn**. Tiene la opción de crear columnas, editar, borrar, en caso de que no exista la base de datos, ésta se creará.

**Valores**

* **Nombre de la tabla**: (Solo habilitado para agregar columnas ADD COLUMN).
* **Nombre de la columna**: Ingrese el nombre de la columna.
* **Tipo**: Ingrese si será VARCHAR, FLOAT o INTEGER.
* **Valor**: Ingrese el valor de la columna (Puede dejar el campo vacío).

* **Asignación de valor**: Habilita o deshabilita el campo Valor.
* **Clave primaria**: Habilita la clave PRIMARY KEY de la columna.
* **Única**: Habilita la clave UNIQUE de la columna.
* **Autoincrementable**: Habilita la clave AUTOINCREMENT de la columna.

***Eliminar tablas***
* **Nombre de la tabla**: Ingrese el nombre de la tabla. En caso de que no exista, lanzará un mensaje (sqlite_TableExists).

***Modificar columnas***
* **Nombre de la tabla**: Ingresa el nombre de la tabla. En caso de que no exista lanzará un mensaje (sqlite_TableExists).
* **Nombre de la columna**: Ingresa el nombre de la tabla. En caso de que no exista lanzará un mensaje.

***Agregar columnas***
* **Habilitar Valores**: Habilita los valores AFTER/BEFORE y el nombre de la columna. En caso de deshabilitarlos no tomará esos valores.