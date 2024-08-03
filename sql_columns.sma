#include <amxmisc>
#include <sqlx>

#pragma semicolon 1

#define SQL_DATABASE "SQL_DataBase"
#define SQL_DRIVE "sqlite"
#define SZPREFIX "!g[AMXX]!y"

#define MAX_COLUMNS 35

enum _:COLUMNS_STRUCT
{
    COLUMN_NAME,
    COLUMN_TYPE,
    COLUMN_VALUE,
    COLUMN_ANEXO
};

enum _:TYPE_STRUCT
{
    TYPE_STRING[12],
    TYPE_ANEXO[32]
};

enum _:COLUMN_TYPE_STRUCT
{
    TYPE_UNIQUE,
    TYPE_PRIMARY_KEY,
    TYPE_AUTOINCREMENT,
    TYPE_VALUE
};

new const COLUMN_TYPE_STRING[][TYPE_STRUCT] =
{
    { "INTEGER", "INTEGER" },
    { "FLOAT", "float" },
    { "VARCHAR", "varchar" }
};

enum _:MESSAGEMODES_STRUCT
{
    CREAR_NOMBRE_DE_LA_TABLA,
    NOMBRE_DE_LA_TABLA,
    NOMBRE_DE_LA_COLUMNA,
    VALOR_DE_LA_COLUMNA,
    SELECCIONAR_TABLA,
    SELECCIONAR_COLUMNA,
    SELECCIONAR_VALOR,
    BORRAR_TABLA,
    AGREGAR_COLUMNA,
    // NOMBRE_TABLA,
    // NOMBRE_COLUMNA
};

new const MESSAGEMODES[][] =
{
    "CREAR_NOMBRE_DE_LA_TABLA",
    "NOMBRE_DE_LA_TABLA",
    "NOMBRE_DE_LA_COLUMNA",
    "VALOR_DE_LA_COLUMNA",
    "SELECCIONAR_TABLA",
    "SELECCIONAR_COLUMNA",
    "SELECCIONAR_VALOR",
    "BORRAR_TABLA",
    "AGREGAR_COLUMNA",
    // "NOMBRE_COLUMNA",
    // "NOMBRE_TABLA",
};

new g_table[32];
new g_column[MAX_COLUMNS][COLUMNS_STRUCT][32];
new g_column_type[MAX_COLUMNS][COLUMN_TYPE_STRUCT];
new Handle:g_sql_connection;
new Handle:g_sql_htuple;
new g_sql_error[512];
new g_column_create[33];
new g_column_edit[33];
new g_column_change[33], g_change[33];
new g_column_selected[33];
new g_table_view[33][32];
new g_column_view[33][32];
new g_value_view[33][32];
new g_column_add[33];
new g_column_add_order[33];
new g_column_add_selection[33][32];
new g_messagemode[33];
new g_database_exists = 0;
new g_connection = 0;
new g_error;

public plugin_init()
{
    register_plugin("SQL Columns", "1.0", "Cristian'");
    
    register_clcmd("say /db", "clcmd_table");
    
    register_menu("Show Menu Table", (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<8)|(1<<9), "handled_show_menu_table");
    register_menu("Show Create Database", (1<<0)|(1<<1)|(1<<9), "handled_show_create_database");
    register_menu("Show Create Column", (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), "handled_show_create_column");
    register_menu("Show Delete Function", (1<<0)|(1<<1)|(1<<9), "handled_show_delete_function");
    register_menu("Show Edit Column", (1<<0)|(1<<1)|(1<<2)|(1<<8)|(1<<9), "handled_show_edit_column");
    register_menu("Show Edit Type Column", (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<9), "handled_show_edit_type_column");
    
    new i;
    
    for (i = 0; i < sizeof(MESSAGEMODES); i++)
        register_clcmd(MESSAGEMODES[i], "handled_messagemodes");
    
    sqlx_init();
    
    new file[65];
    formatex(file, 64, "addons/amxmodx/data/sqlite3/%s.sq3", SQL_DATABASE);
    
    if (file_exists(file)) 
    {
        g_connection = 1;
        g_database_exists = 1;
    }
}

public client_putinserver(id)
    resetvars(id);

public clcmd_table(id)
{
    if (!(get_user_flags(id) & ADMIN_RCON))
        return PLUGIN_HANDLED;
    
    static menu[256], len;
    len = 0;
    
    len += formatex(menu[len], charsmax(menu) - len, "\yEditor de base de datos^n^n\r1. \wCrear una base de datos^n\r2. \wEditar columnas creadas^n\r3. \wEditar el valor de una columna^n^n\r4. \yBorrar tablas / columnas^n^n\r9. \wGenerar base de datos^n^n\r0. \wSalir");
    
    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<8)|(1<<9), menu, -1, "Show Menu Table");
    return PLUGIN_HANDLED;
}

public handled_show_menu_table(id, key)
{
    switch(key)
    {
        case 0: show_create_database(id);
        case 1: show_edit_database(id);
        case 2: 
        {
            if (!g_database_exists)
            {
                chat_color(id, "%s !yNo existe una base de datos.", SZPREFIX);
                clcmd_table(id);
                return PLUGIN_HANDLED;
            }
            
            show_edit_type_column(id);
        }
        case 3: 
        {
            if (!g_database_exists)
            {
                chat_color(id, "%s !yNo existe una base de datos.", SZPREFIX);
                clcmd_table(id);
                return PLUGIN_HANDLED;
            }
            
            show_menu(id, (1<<0)|(1<<1)|(1<<9), "\yBorrar tabla / columna^n^n\r1. \wTabla^n\r2. \dColumna^n^n^n\r0. \wAtrás", -1, "Show Delete Function");
        }
        case 8: create_database(id);
    }
    
    return PLUGIN_HANDLED;
}

public handled_show_delete_function(id, key)
{
    switch(key)
    {
        case 0: client_cmd(id, "messagemode BORRAR_TABLA"), g_messagemode[id] = BORRAR_TABLA;
        // case 1: client_cmd(id, "messagemode NOMBRE_TABLA"), g_messagemode[id] = NOMBRE_TABLA;
        case 1: 
        {
            chat_color(id, "%s !yEsta opción está en construcción.", SZPREFIX);
            show_menu(id, (1<<0)|(1<<1)|(1<<9), "\yBorrar tabla / columna^n^n\r1. \wTabla^n\r2. \dColumna^n^n^n\r0. \wAtrás", -1, "Show Delete Function");
        }
        case 9: clcmd_table(id);
    }
    
    return PLUGIN_HANDLED;
}

show_edit_database(id)
{
    static menu, i;
    menu = menu_create("\yEditar columnas creadas", "handled_show_edit_database");
    
    for (i = 0; i < g_column_create[id]; i++)
        menu_additem(menu, g_column[i][COLUMN_NAME]);

    if (!menu_items(menu))
    {
        chat_color(id, "%s !yNo hay columnas creadas.", SZPREFIX);
        clcmd_table(id);
    }
        
    
    menu_setprop(menu, MPROP_BACKNAME, "Atrás");    
    menu_setprop(menu, MPROP_NEXTNAME, "Siguiente");    
    menu_setprop(menu, MPROP_EXITNAME, "Salir");    
    menu_display(id, menu);
}

public handled_show_edit_database(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        clcmd_table(id);
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }
    
    g_column_edit[id] = 1; 
    g_column_selected[id] = item;
    menu_destroy(menu);
    show_create_column(id);
    return PLUGIN_HANDLED;
}

show_edit_type_column(id)
{
    static menu[256];
    formatex(menu, charsmax(menu), "\yEditar columna^n^n\r1. \wEditar el valor de una columna^n\r2. \wAgregar columna a una tabla^n\r3. %sHabilitar valores \y(ADD COLUMN)^n^n\r4. %sAgregar: \y%s^n\r5. %sColumna: \y%s^n^n\r0. Atrás", 
    (g_column_add[id]) ? "\w" : "\d", (g_column_add[id]) ? "\y" : "\d", (g_column_add[id] == 1) ? (g_column_add_order[id] == 1) ? "BEFORE" : "AFTER" : "-", (g_column_add[id]) ? "\w" : "\d", (g_column_add[id] == 1) ? g_column_add_selection[id] : "-");

    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<9), menu, -1, "Show Edit Type Column");
}

public handled_show_edit_type_column(id, key)
{
    switch(key)
    {
        case 0: 
        {    
            show_edit_column(id);
            return PLUGIN_HANDLED;
        }
        case 1: 
        {
            g_change[id] = 1;
            show_create_column(id);
            return PLUGIN_HANDLED;
        }
        case 2: g_column_add[id] = !(g_column_add[id]);
        case 3: g_column_add_order[id] = !(g_column_add_order[id]);
        case 4: client_cmd(id, "messagemode AGREGAR_COLUMNA"), g_messagemode[id] = AGREGAR_COLUMNA;
        case 9: 
        {
            clcmd_table(id);
            return PLUGIN_HANDLED;
        }
    }
    
    show_edit_type_column(id);
    return PLUGIN_HANDLED;
}

show_edit_column(id)
{
    static menu[256];
    formatex(menu, charsmax(menu), "\yEditar el valor de una columna^n^n\r* \wNombre de la tabla: \y%s^n\r* \wNombre de la columna: \y%s^n\r* \wValor: \y%s^n^n\r9. \wEditar la columna^n\r0. \wAtrás",
    g_table_view[id], g_column_view[id], g_value_view[id]);
    
    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<8)|(1<<9), menu, -1, "Show Edit Column");
    return PLUGIN_HANDLED;
}

public handled_show_edit_column(id, key)
{
    switch(key)
    {
        case 0: client_cmd(id, "messagemode SELECCIONAR_TABLA"), g_messagemode[id] = SELECCIONAR_TABLA;
        case 1: client_cmd(id, "messagemode SELECCIONAR_COLUMNA"), g_messagemode[id] = SELECCIONAR_COLUMNA;
        case 2: client_cmd(id, "messagemode SELECCIONAR_VALOR"), g_messagemode[id] = SELECCIONAR_VALOR;
        case 8: 
        {
            new Handle:query;
            query = SQL_PrepareQuery(g_sql_connection, "UPDATE '%s' SET %s = %s", g_table_view[id], g_column_view[id], g_value_view[id]);
            
            if (!SQL_Execute(query))
                sql_query_error(query, id);
            else
            {
                SQL_FreeHandle(query); 
                chat_color(id, "%s !yLa columna !g%s!y de la tabla !g%s!y fue modificada a !g%s!y.", SZPREFIX, g_column_view[id], g_table_view[id], g_value_view[id]);
                
                g_table_view[id][0] = EOS;
                g_column_view[id][0] = EOS;
                g_value_view[id][0] = EOS;
            }
            
            show_edit_column(id);
        }
        case 9: show_edit_type_column(id);
    }
    
    return PLUGIN_HANDLED;
}

public handled_messagemodes(id)
{
    if (!(get_user_flags(id) & ADMIN_RCON))
        return PLUGIN_HANDLED;
    
    new args[32];
    read_args(args, charsmax(args));
    remove_quotes(args);
    trim(args);
    
    switch(g_messagemode[id])
    {
        case CREAR_NOMBRE_DE_LA_TABLA:
        {
            if (strlen(args) < 2)
            {
                show_create_database(id);
                return PLUGIN_HANDLED;
            }
            
            if (!isalpha(args[0]))
            {
                show_create_column(id);
                chat_color(id, "%s !ySolo carácteres alfabéticos.", SZPREFIX);
                return PLUGIN_HANDLED;
            }
            
            if (g_database_exists)
            {
                if (sqlite_TableExists(g_sql_connection, args))
                {
                    chat_color(id, "%s !yYa existe una tabla con el nombre !g%s!y.", SZPREFIX, args);
                    show_create_database(id);
                    return PLUGIN_HANDLED;
                }
                
                copy(g_table, 31, args);
                show_create_database(id);
            }
            else
            {
                copy(g_table, 31, args);
                show_create_database(id);
            }
        }
        case NOMBRE_DE_LA_TABLA:
        {
            if (strlen(args) < 2)
            {
                show_create_column(id);
                return PLUGIN_HANDLED;
            }
            
            if (!isalpha(args[0]))
            {
                show_create_column(id);
                chat_color(id, "%s !ySolo carácteres alfabéticos.", SZPREFIX);
                return PLUGIN_HANDLED;
            }
            
            if (!g_change[id])
            {
                chat_color(id, "%s !yNo está el modo de editar activado.", SZPREFIX);
                return PLUGIN_HANDLED;
            }
            
            if (g_database_exists)
            {
                if (!sqlite_TableExists(g_sql_connection, args))
                {
                    chat_color(id, "%s !yLa tabla !g%s!y no existe en la base de datos.", SZPREFIX, args);
                    show_create_column(id);
                    return PLUGIN_HANDLED;
                }
                
                copy(g_table_view[id], 31, args);
                show_create_column(id);
            }
            else
            {
                copy(g_table_view[id], 31, args);
                show_create_database(id);
            } 
        }
        case NOMBRE_DE_LA_COLUMNA:
        {
            if (strlen(args) < 2)
            {
                show_create_column(id);        
                return PLUGIN_HANDLED;
            }
            
            if (!isalpha(args[0]))
            {
                show_create_column(id);
                chat_color(id, "%s !ySolo carácteres alfabéticos.", SZPREFIX);
                return PLUGIN_HANDLED;
            }
            
            if (!g_change[id])
                copy(g_column[(g_column_edit[id] == 1) ? g_column_selected[id] : g_column_create[id]][COLUMN_NAME], 31, args);
            else
            {
                new Handle:query;
                query = SQL_PrepareQuery(g_sql_connection, "SELECT %s FROM '%s'", args, g_table_view[id]);
                
                if (!SQL_Execute(query))
                {
                    copy(g_column[g_column_change[id]][COLUMN_NAME], 31, args);
                    SQL_FreeHandle(query);
                }
                else        
                {
                    chat_color(id, "%s !yYa existe una columna llamada !g%s!y.", SZPREFIX, args);
                    SQL_FreeHandle(query);
                }
            }
            
            show_create_column(id);
        }
        case VALOR_DE_LA_COLUMNA: 
        {
            if (!g_change[id])
                copy(g_column[(g_column_edit[id] == 1) ? g_column_selected[id] : g_column_create[id]][COLUMN_VALUE], 31, args);
            else
                copy(g_column[g_column_change[id]][COLUMN_VALUE], 31, args);
            show_create_column(id);
        }
        case SELECCIONAR_TABLA:
        {
            if (!sqlite_TableExists(g_sql_connection, args))
            { 
                chat_color(id, "%s !yLa tabla !g%s!y no existe en la base de datos.", SZPREFIX, args);
                show_edit_column(id);
                return PLUGIN_HANDLED;
            }
            
            copy(g_table_view[id], 31, args);
            show_edit_column(id);
        }
        case SELECCIONAR_COLUMNA:
        {
            if (strlen(args) < 2)
            {
                chat_color(id, "%s !yEl valor es incorrecto.", SZPREFIX, args);
                clcmd_table(id);
                return PLUGIN_HANDLED;
            }
            
            new Handle:query;
            query = SQL_PrepareQuery(g_sql_connection, "SELECT %s FROM '%s'", args, g_table_view[id]);
            
            if (!SQL_Execute(query))
            {
                chat_color(id, "%s !yLa columna !g%s!y no existe en la tabla.", SZPREFIX, args);
                show_edit_column(id);
                SQL_FreeHandle(query);
                return PLUGIN_HANDLED;
            }
            else
                SQL_FreeHandle(query);
            
            copy(g_column_view[id], 31, args);
            show_edit_column(id);
        }
        case SELECCIONAR_VALOR:
        {
            if (!strlen(args))
            {
                chat_color(id, "%s !yNo podés dejar el campo vacío.", SZPREFIX, args);
                show_edit_column(id);
                return PLUGIN_HANDLED;
            }
            
            copy(g_value_view[id], 31, args);
            show_edit_column(id);
        }
        case BORRAR_TABLA:
        {
            if (!strlen(args))
            {
                chat_color(id, "%s !yNo podés dejar el campo vacío.", SZPREFIX, args);
                show_menu(id, (1<<0)|(1<<1)|(1<<9), "\yBorrar tabla / columna^n^n\r1. \wTabla^n\r2. \dColumna^n^n^n\r0. \wAtrás", -1, "Show Delete Function");
                return PLUGIN_HANDLED;
            }
            
            if (!sqlite_TableExists(g_sql_connection, args))
            { 
                chat_color(id, "%s !yLa tabla !g%s!y no existe en la base de datos.", SZPREFIX, args);
                show_menu(id, (1<<0)|(1<<1)|(1<<9), "\yBorrar tabla / columna^n^n\r1. \wTabla^n\r2. \dColumna^n^n^n\r0. \wAtrás", -1, "Show Delete Function");
                return PLUGIN_HANDLED;
            }
            
            new Handle:query;
            query = SQL_PrepareQuery(g_sql_connection, "DROP TABLE '%s'", args);
            
            if (!SQL_Execute(query))
                sql_query_error(query, id);
            else
            {
                chat_color(id, "%s !yLa tabla !g%s!y fue eliminada de la base de datos.", SZPREFIX, args);
                SQL_FreeHandle(query);
            }
            
            show_menu(id, (1<<0)|(1<<1)|(1<<9), "\yBorrar tabla / columna^n^n\r1. \wTabla^n\r2. \dColumna^n^n^n\r0. \wAtrás", -1, "Show Delete Function");
        }
        // case NOMBRE_TABLA:
        // {
            // if (!strlen(args))
            // {
                // chat_color(id, "%s !yNo podés dejar el campo vacío.", SZPREFIX, args);
                // show_menu(id, (1<<0)|(1<<1)|(1<<9), "\yBorrar tabla / columna^n^n\r1. \wTabla^n\r2. \dColumna^n^n^n\r0. \wAtrás", -1, "Show Delete Function");
                // return PLUGIN_HANDLED;
            // }
            
            // if (!sqlite_TableExists(g_sql_connection, args))
            // { 
                // chat_color(id, "%s !yLa tabla !g%s!y no existe en la base de datos.", SZPREFIX, args);
                // show_menu(id, (1<<0)|(1<<1)|(1<<9), "\yBorrar tabla / columna^n^n\r1. \wTabla^n\r2. \dColumna^n^n^n\r0. \wAtrás", -1, "Show Delete Function");
                // return PLUGIN_HANDLED;
            // }
            
            // copy(g_table_view[id], 31, args);
            // client_cmd(id, "messagemode NOMBRE_COLUMNA");
            // g_messagemode[id] = NOMBRE_COLUMNA;
        // }
        // case NOMBRE_COLUMNA:
        // {
            // if (!strlen(args))
            // {
                // chat_color(id, "%s !yNo podés dejar el campo vacío.", SZPREFIX, args);
                // show_menu(id, (1<<0)|(1<<1)|(1<<9), "\yBorrar tabla / columna^n^n\r1. \wTabla^n\r2. \dColumna^n^n^n\r0. \wAtrás", -1, "Show Delete Function");
                // return PLUGIN_HANDLED;
            // } 
            
            // new Handle:query;
            // query = SQL_PrepareQuery(g_sql_connection, "ALTER TABLE '%s' DROP COLUMN '%s'", g_table_view[id], args);
            
            // if (!SQL_Execute(query))
                // sql_query_error(query, id);
            // else
            // {
                // chat_color(id, "%s !yLa columna !g%s!y de la tabla !g%s!y fue eliminada de la base de datos.", SZPREFIX, args, g_table_view[id]);
                // SQL_FreeHandle(query);
            // }
        // }
        case AGREGAR_COLUMNA:
        {
            if (strlen(args) < 2)
            {
                show_edit_type_column(id);        
                return PLUGIN_HANDLED;
            }
            
            if (!isalpha(args[0]))
            {
                show_edit_type_column(id);
                chat_color(id, "%s !ySolo carácteres alfabéticos.", SZPREFIX);
                return PLUGIN_HANDLED;
            }
            
            copy(g_column_add_selection[id], 31, args);
            show_edit_type_column(id);
        }
    }
    
    return PLUGIN_HANDLED;
}
 
public show_create_database(id)
{
    g_column_edit[id] = 0;
    static menu[128], len;
    len = 0;
    
    len += formatex(menu[len], charsmax(menu) - len, "\yCrear base de datos^n^n\r1. \wNombre de la tabla: \y%s^n^n\r2. %sCrear una columna^n^n^n\r0. \wSalir", g_table, (strlen(g_table) > 0) ? "\w" : "\d");
    
    show_menu(id, (1<<0)|(1<<1)|(1<<9), menu, -1, "Show Create Database");
    
    return PLUGIN_HANDLED;
}

public handled_show_create_database(id, key)
{
    switch(key)
    {
        case 0: g_change[id] = 0, client_cmd(id, "messagemode CREAR_NOMBRE_DE_LA_TABLA"), g_messagemode[id] = CREAR_NOMBRE_DE_LA_TABLA;
        case 1: 
        {
            if (strlen(g_table) > 0)
                show_create_column(id);
            else
            {
                chat_color(id, "%s !yTenés que poner el nombre de la tabla antes de crear una columna.", SZPREFIX); 
                show_create_database(id);
                return PLUGIN_HANDLED;
            }
        }
        case 9: clcmd_table(id);
    }
    
    return PLUGIN_HANDLED;
}

public show_create_column(id)
{
    static menu[300], column[32], table[32], type[32], value[32], unique[5], cvalue[5], primary_key[5], autoincrement[5], edit[32], tittle[32], type_column, len;
    len = 0;
    
    if (!g_change[id])
    {
        if (g_column_edit[id])
        {
            copy(column, 31, g_column[g_column_selected[id]][COLUMN_NAME]);
            copy(type, 31, g_column[g_column_selected[id]][COLUMN_TYPE]);
            copy(value, 31, g_column[g_column_selected[id]][COLUMN_VALUE]);
            
            format(cvalue, 4, "%s", (g_column_type[g_column_selected[id]][TYPE_VALUE]) ? "\w" : "\d");
            format(unique, 4, "%s", (g_column_type[g_column_selected[id]][TYPE_UNIQUE]) ? "\w" : "\d");
            format(primary_key, 4, "%s", (g_column_type[g_column_selected[id]][TYPE_PRIMARY_KEY]) ? "\w" : "\d");
            format(autoincrement, 4, "%s", (g_column_type[g_column_selected[id]][TYPE_AUTOINCREMENT]) ? "\w" : "\d");
            
            type_column = g_column_type[g_column_selected[id]][TYPE_VALUE];
            
            formatex(table, 31, "* \dNombre de la tabla: \y-", g_table_view[id]);
            copy(tittle, 31, "Editar columna creada");
            copy(edit, 31, "Editar la columna creada");
        }
        else
        {
            copy(column, 31, g_column[g_column_create[id]][COLUMN_NAME]);
            copy(type, 31, g_column[g_column_create[id]][COLUMN_TYPE]);
            copy(value, 31, g_column[g_column_create[id]][COLUMN_VALUE]);
            
            format(cvalue, 4, "%s", (g_column_type[g_column_create[id]][TYPE_VALUE]) ? "\w" : "\d");
            format(unique, 4, "%s", (g_column_type[g_column_create[id]][TYPE_UNIQUE]) ? "\w" : "\d");
            format(primary_key, 4, "%s", (g_column_type[g_column_create[id]][TYPE_PRIMARY_KEY]) ? "\w" : "\d");
            format(autoincrement, 4, "%s", (g_column_type[g_column_create[id]][TYPE_AUTOINCREMENT]) ? "\w" : "\d");
            
            type_column = g_column_type[g_column_create[id]][TYPE_VALUE];
            
            formatex(table, 31, "* \dNombre de la tabla: \y-", g_table_view[id]);
            copy(tittle, 31, "Crear columna");
            copy(edit, 31, "Crear la columna");
        }
    }
    else
    {
        copy(column, 31, g_column[g_column_change[id]][COLUMN_NAME]);
        copy(type, 31, g_column[g_column_change[id]][COLUMN_TYPE]);
        copy(value, 31, g_column[g_column_change[id]][COLUMN_VALUE]);
        
        format(cvalue, 4, "%s", (g_column_type[g_column_change[id]][TYPE_VALUE]) ? "\w" : "\d");
        format(unique, 4, "%s", (g_column_type[g_column_change[id]][TYPE_UNIQUE]) ? "\w" : "\d");
        format(primary_key, 4, "%s", (g_column_type[g_column_change[id]][TYPE_PRIMARY_KEY]) ? "\w" : "\d");
        format(autoincrement, 4, "%s", (g_column_type[g_column_change[id]][TYPE_AUTOINCREMENT]) ? "\w" : "\d");
        
        type_column = g_column_type[g_column_change[id]][TYPE_VALUE];
        
        formatex(table, 31, "* \wNombre de la tabla: \y%s", g_table_view[id]);
        copy(tittle, 31, "Agregar columnas");
        copy(edit, 31, "Agregar columna a la tabla");
    }
    
    len += formatex(menu[len], charsmax(menu) - len, "\y%s^n^n%s^n\r* \wNombre de la columna: \y%s^n\r* \yTipo: \d%s^n\r* %sValor: \y%s^n^n\r* \yAsignación de valor: \r%s^n^n\r* %sPrimary Key^n\r* %sAutoincrement^n\r* %sUnique^n^n\r9. \w%s^n\r0. \wVolver atrás", 
    tittle, table, column, type, cvalue, (type_column) ? value : "NINGUNO", ((type_column)) ? "Sí" : "No", primary_key, autoincrement, unique, edit);
    
    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)|(1<<9), menu, -1, "Show Create Column");
    
    return PLUGIN_HANDLED;
}

public handled_show_create_column(id, key)
{
    switch(key)
    {
        case 0: 
        {
            if (!g_change[id])
            {
                chat_color(id, "%s !yEsto está disponible solo para crear columnas en una tabla.", SZPREFIX);
                show_create_column(id);
                return PLUGIN_HANDLED;
            }
            
            client_cmd(id, "messagemode NOMBRE_DE_LA_TABLA"), g_messagemode[id] = NOMBRE_DE_LA_TABLA;
        }
        case 1: client_cmd(id, "messagemode NOMBRE_DE_LA_COLUMNA"), g_messagemode[id] = NOMBRE_DE_LA_COLUMNA;
        case 2: 
        {
            show_column_type(id); 
            return PLUGIN_HANDLED;
        }
        case 3: client_cmd(id, "messagemode VALOR_DE_LA_COLUMNA"), g_messagemode[id] = VALOR_DE_LA_COLUMNA;
        case 4: 
        {
            if (!g_change[id])
                g_column_type[(g_column_edit[id] == 1) ? g_column_selected[id] : g_column_create[id]][TYPE_VALUE] = !(g_column_type[(g_column_edit[id] == 1) ? g_column_selected[id] : g_column_create[id]][TYPE_VALUE]);
            else
                g_column_type[g_column_change[id]][TYPE_VALUE] = !(g_column_type[g_column_change[id]][TYPE_VALUE]);
        }
        case 5: 
        {
            if (!g_change[id])
                g_column_type[(g_column_edit[id] == 1) ? g_column_selected[id] : g_column_create[id]][TYPE_PRIMARY_KEY] = !(g_column_type[(g_column_edit[id] == 1) ? g_column_selected[id] : g_column_create[id]][TYPE_PRIMARY_KEY]);
            else
                g_column_type[g_column_change[id]][TYPE_PRIMARY_KEY] = !(g_column_type[g_column_change[id]][TYPE_PRIMARY_KEY]);
        }
        case 6: 
        {
            if (!g_change[id])
                g_column_type[(g_column_edit[id] == 1) ? g_column_selected[id] : g_column_create[id]][TYPE_AUTOINCREMENT] = !(g_column_type[(g_column_edit[id] == 1) ? g_column_selected[id] : g_column_create[id]][TYPE_AUTOINCREMENT]);
            else
                g_column_type[g_column_change[id]][TYPE_AUTOINCREMENT] = !(g_column_type[g_column_change[id]][TYPE_AUTOINCREMENT]);
        }
        case 7: 
        {
            if (!g_change[id])
                g_column_type[(g_column_edit[id] == 1) ? g_column_selected[id] : g_column_create[id]][TYPE_UNIQUE] = !(g_column_type[(g_column_edit[id] == 1) ? g_column_selected[id] : g_column_create[id]][TYPE_UNIQUE]);
            else
                g_column_type[g_column_change[id]][TYPE_UNIQUE] = !(g_column_type[g_column_change[id]][TYPE_UNIQUE]);
        }
        case 8: 
        {
            if (!g_change[id])
            {
                if (g_column_edit[id])
                {
                    client_print(id, print_center, "La columna %s fue modificada", g_column[g_column_selected[id]][COLUMN_NAME]);
                    show_edit_database(id);
                    return PLUGIN_HANDLED;
                }
                
                if (!strlen(g_column[g_column_create[id]][COLUMN_TYPE]))
                {
                    show_create_column(id);
                    chat_color(id, "%s !yTenés que seleccionar el tipo de columna antes de crearla.", SZPREFIX);
                    return PLUGIN_HANDLED;
                }
                
                g_column_create[id]++;
                copy(g_column_edit[g_column_create[id]], 31, g_column[g_column_create[id]][COLUMN_NAME]);
                client_print(id, print_center, "La columna %s fue creada con éxito", g_column[g_column_create[id]][COLUMN_NAME]);
                show_create_database(id);
            }
            else
            {
                new text[2][128];
                format(text[0], 127, " '%s'", g_column[g_column_change[id]][COLUMN_VALUE]);
                
                if (g_column_add[id])
                    format(text[1], 127, " %s '%s'", (g_column_add_order[id] == 1) ? "BEFORE" : "AFTER", g_column_add_selection[id]);
                else
                    format(text[1], 127, "");
                
                new Handle:query;
                query = SQL_PrepareQuery(g_sql_connection, "ALTER TABLE '%s' ADD COLUMN '%s' %s%s%s%s NOT NULL%s%s%s", g_table_view[id],
                g_column[g_column_change[id]][COLUMN_NAME], g_column[g_column_change[id]][COLUMN_ANEXO], 
                (g_column_type[g_column_change[id]][TYPE_PRIMARY_KEY] == 1) ? " PRIMARY KEY" : "", (g_column_type[g_column_change[id]][TYPE_AUTOINCREMENT] == 1) ? " AUTOINCREMENT" : "", (g_column_type[g_column_change[id]][TYPE_UNIQUE] == 1) ? " UNIQUE" : "", 
                (g_column_type[g_column_change[id]][TYPE_VALUE] == 1) ? " DEFAULT": "", (g_column_type[g_column_change[id]][TYPE_VALUE] == 1) ? ((strlen(g_column[g_column_change[id]][COLUMN_VALUE]) > 0) ? text[0] : " ''") : "", text[1]);
            
                if (!SQL_Execute(query))
                    sql_query_error(query, id);
                else
                {
                    chat_color(id, "%s !yColumna creada.", SZPREFIX);
                    chat_color(id, "%s !yNombre: !g%s!y - Tabla: !g%s!y.", SZPREFIX, g_column[g_column_change[id]][COLUMN_NAME], g_table_view[id]);
                    SQL_FreeHandle(query);
                }
            }
            
            return PLUGIN_HANDLED;
        }
        case 9: 
        {
            if (!g_change[id])
                clcmd_table(id);
            else
                show_edit_type_column(id);
            
            return PLUGIN_HANDLED;
        }
    }
    
    show_create_column(id);
    return PLUGIN_HANDLED;
}
  
show_column_type(id)
{
    static menu, i;
    menu = menu_create("\yTipo de columna", "handled_show_column_type");
    
    for (i = 0; i < sizeof(COLUMN_TYPE_STRING); i++)
        menu_additem(menu, COLUMN_TYPE_STRING[i]);
    
    menu_setprop(menu, MPROP_BACKNAME, "Atrás");
    menu_setprop(menu, MPROP_NEXTNAME, "Siguiente");
    menu_setprop(menu, MPROP_EXITNAME, "Volver");
    
    menu_display(id, menu);
}

public handled_show_column_type(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }
    
    copy(g_column[(g_column_edit[id] == 1) ? g_column_selected[id] : g_column_create[id]][COLUMN_TYPE], 31, COLUMN_TYPE_STRING[item][TYPE_STRING]);
    copy(g_column[(g_column_edit[id] == 1) ? g_column_selected[id] : g_column_create[id]][COLUMN_ANEXO], 31, COLUMN_TYPE_STRING[item][TYPE_ANEXO]);
    
    show_create_column(id);
    return PLUGIN_HANDLED;
}

public handled_create_column_name(id)
{
    static text[32];
    read_args(text, charsmax(text));
    remove_quotes(text);
    trim(text);
    
    if (!strlen(text))
    {
        show_create_column(id);
        return;
    }
    
    copy(g_column[(g_column_edit[id] == 1) ? g_column_selected[id] : g_column_create[id]][COLUMN_NAME], 31, text);
    show_create_column(id);
}

public handled_create_column_value(id)
{
    static text[32];
    read_args(text, charsmax(text));
    remove_quotes(text);
    trim(text);
    
    copy(g_column[(g_column_edit[id] == 1) ? g_column_selected[id] : g_column_create[id]][COLUMN_VALUE], 31, text);
    show_create_column(id);
}

sqlx_init()
{    
    new get_type[12];
    
    SQL_SetAffinity(SQL_DRIVE);
    SQL_GetAffinity(get_type, charsmax(get_type));
    
    g_sql_htuple = SQL_MakeDbTuple("", "", "", SQL_DATABASE);
    
    if (g_sql_htuple == Empty_Handle)
    {
        log_to_file("SQL_HTuple.log", "%s", g_sql_error);
        set_fail_state(g_sql_error);
    }
}

create_database(id)
{
    if (!g_connection)
    {
        g_connection = 1;
        g_sql_connection = SQL_Connect(g_sql_htuple, g_error, g_sql_error, 511);
    }
    
    new table[1024], len;
    len = 0;
    
    new i;
    
    console_print(id, "*** COLUMNA ***");
    console_print(id, "");
    console_print(id, "");
    console_print(id, "");
    
    for (i = 0; i < g_column_create[id]; i++)
    {
        new text[128];
        format(text, 127, " '%s'", g_column[i][COLUMN_VALUE]);
        
        len += formatex(table[len], charsmax(table) - len, "%s %s%s%s%s NOT NULL%s%s%s", 
        g_column[i][COLUMN_NAME], g_column[i][COLUMN_ANEXO], 
        (g_column_type[i][TYPE_PRIMARY_KEY] == 1) ? " PRIMARY KEY" : "", (g_column_type[i][TYPE_AUTOINCREMENT] == 1) ? " AUTOINCREMENT" : "", (g_column_type[i][TYPE_UNIQUE] == 1) ? " UNIQUE" : "", 
        (g_column_type[i][TYPE_VALUE] == 1) ? " DEFAULT": "", (g_column_type[i][TYPE_VALUE] == 1) ? ((strlen(g_column[i][COLUMN_VALUE]) > 0) ? text : " ''") : "", ((i + 1) == g_column_create[id]) ? "" : ", ");
        
        console_print(id, table);
    }
    
    console_print(id, "");
    console_print(id, "");
    console_print(id, "");
    console_print(id, "*** COLUMNA ***");
    
    new Handle:query;
    query = SQL_PrepareQuery(g_sql_connection, "CREATE TABLE IF NOT EXISTS '%s' ( %s )", g_table, table);
    
    if (!SQL_Execute(query))
        sql_query_error(Handle:query, 0);
    else 
    {
        SQL_FreeHandle(query);
        client_print(id, print_center, "LA TABLA FUE CREADA CON EXITO");
        
        if (!g_database_exists)
        {
            chat_color(id, "%s !ySe creó una base de datos con el nombre !g%s!y.", SZPREFIX, SQL_DATABASE);
            chat_color(id, "%s !yArchivo: !g%s!y - Nombre de la tabla: !g%s!y - Columnas: !g%d / %d!y.", SZPREFIX, SQL_DATABASE, g_table, g_column_create[id], MAX_COLUMNS);
            chat_color(id, "%s !yVer consola para ver la consulta.", SZPREFIX);
        }
        else
        {
            chat_color(id, "%s !yLa tabla fue creada con éxito.", SZPREFIX);
            chat_color(id, "%s !yArchivo: !g%s!y - Nombre de la tabla: !g%s!y - Columnas: !g%d / %d!y.", SZPREFIX, SQL_DATABASE, g_table, g_column_create[id], MAX_COLUMNS);
            chat_color(id, "%s !yVer consola para ver la consulta.", SZPREFIX);
        }    
        
        g_database_exists = 1;
    }
    
    resetvars(id);
    
    return PLUGIN_HANDLED;
}

resetvars(id)
{
    new j, i;
        
    for (i = 0; i < g_column_create[id]; i++)
    {
        for (j = 0; j < 4; j++)
            g_column[i][j][0] = EOS;
    }
    
    g_table[0] = EOS;
    g_column_create[id] = 0;
    g_column_edit[id] = 0;
    g_column_change[id] = 0;
    g_change[id] = 0;
    g_column_selected[id] = 0;
    g_table_view[id][0] = EOS;
    g_column_view[id][0] = EOS;
    g_value_view[id][0] = EOS;
    g_column_add_selection[id][0] = EOS;
    g_column_add[id] = 0;
    g_column_add_order[id] = 0;
    g_messagemode[id] = CREAR_NOMBRE_DE_LA_TABLA;
}

sql_query_error(Handle:query, id)
{
    static error[56];
    SQL_QueryError(query, error, 55);
        
    chat_color(id, "%s !yError: !g%s!y.", SZPREFIX, error);
    SQL_FreeHandle(query);
}

chat_color(id, const input[], any:...)
{
    static message[191];
    vformat(message, 190, input, 3);
    
    replace_all(message, 190, "!g", "^4");
    replace_all(message, 190, "!t", "^3");
    replace_all(message, 190, "!y", "^1");
    
    message_begin((id) ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, get_user_msgid("SayText"), .player = id);
    write_byte((id) ? id : 33);
    write_string(message);
    message_end();
} 