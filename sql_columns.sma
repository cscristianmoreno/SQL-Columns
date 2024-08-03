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
    CREATE_NAME_OF_THE_TAB,
    NAME_OF_THE_TAB,
    NAME_OF_THE_COLUMN,
    VALUE_OF_THE_COLUMN,
    SELECT_TABLE,
    SELECT_COLUMN,
    SELECT_VALUE,
    DELETE_TABLE,
    ADD_COLUMN
};

new const MESSAGEMODES[][] =
{
    "CREATE_NAME_OF_THE_TAB",
    "NAME_OF_THE_TAB",
    "NAME_OF_THE_COLUMN",
    "VALUE_OF_THE_COLUMN",
    "SELECT_TABLE",
    "SELECT_COLUMN",
    "SELECT_VALUE",
    "DELETE_TABLE",
    "ADD_COLUMN"
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
    
    len += formatex(menu[len], charsmax(menu) - len, "\yDatabase editor^n^n\r1. \wCreate a database^n\r2. \wEdit created columns^n\r3. \wEdit the value of a column^n^n\r4. \yDelete tables / columns^n^n\r9. \wGenerate database / column^n^n\r0. \wExit");
    
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
                chat_color(id, "%s !yThere is no database.", SZPREFIX);
                clcmd_table(id);
                return PLUGIN_HANDLED;
            }
            
            show_edit_type_column(id);
        }
        case 3: 
        {
            if (!g_database_exists)
            {
                chat_color(id, "%s !yThere is no database.", SZPREFIX);
                clcmd_table(id);
                return PLUGIN_HANDLED;
            }
            
            show_menu(id, (1<<0)|(1<<1)|(1<<9), "\yDelete table / column^n^n\r1. \wTable^n\r2. \dColumn^n^n^n\r0. \wGo back", -1, "Show Delete Function");
        }
        case 8: create_database(id);
    }
    
    return PLUGIN_HANDLED;
}

public handled_show_delete_function(id, key)
{
    switch(key)
    {
        case 0: client_cmd(id, "messagemode DELETE_TABLE"), g_messagemode[id] = DELETE_TABLE;
        case 1: 
        {
            chat_color(id, "%s !yThis option is under construction.", SZPREFIX);
            show_menu(id, (1<<0)|(1<<1)|(1<<9), "\yDelete table / column^n^n\r1. \wTable^n\r2. \dColumn^n^n^n\r0. \wGo back", -1, "Show Delete Function");
        }
        case 9: clcmd_table(id);
    }
    
    return PLUGIN_HANDLED;
}

show_edit_database(id)
{
    static menu, i;
    menu = menu_create("\yEdit created columns", "handled_show_edit_database");
    
    for (i = 0; i < g_column_create[id]; i++)
        menu_additem(menu, g_column[i][COLUMN_NAME]);

    if (!menu_items(menu))
    {
        chat_color(id, "%s !yNo columns created.", SZPREFIX);
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
    formatex(menu, charsmax(menu), "\yEdit column^n^n\r1. \wEdit the value of a column^n\r2. \wAdd column to a table^n\r3. %sEnable values \y(ADD COLUMN)^n^n\r4. %sAdd: \y%s^n\r5. %sColumn: \y%s^n^n\r0. \wGo back", 
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
        case 4: client_cmd(id, "messagemode ADD_COLUMN"), g_messagemode[id] = ADD_COLUMN;
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
    formatex(menu, charsmax(menu), "\yEdit the value of a column^n^n\r* \wName of the table: \y%s^n\r* \wName of the column: \y%s^n\r* \wValue: \y%s^n^n\r9. \wEdit the column^n\r0. \wGo back",
    g_table_view[id], g_column_view[id], g_value_view[id]);
    
    show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<8)|(1<<9), menu, -1, "Show Edit Column");
    return PLUGIN_HANDLED;
}

public handled_show_edit_column(id, key)
{
    switch(key)
    {
        case 0: client_cmd(id, "messagemode SELECT_TABLE"), g_messagemode[id] = SELECT_TABLE;
        case 1: client_cmd(id, "messagemode SELECT_COLUMN"), g_messagemode[id] = SELECT_COLUMN;
        case 2: client_cmd(id, "messagemode SELECT_VALUE"), g_messagemode[id] = SELECT_VALUE;
        case 8: 
        {
            new Handle:query;
            query = SQL_PrepareQuery(g_sql_connection, "UPDATE '%s' SET %s = %s", g_table_view[id], g_column_view[id], g_value_view[id]);
            
            if (!SQL_Execute(query))
                sql_query_error(query, id);
            else
            {
                SQL_FreeHandle(query); 
                chat_color(id, "%s !yThe values of the column !g%s!y of the table !g%s!y whas modified to !g%s!y.", SZPREFIX, g_column_view[id], g_table_view[id], g_value_view[id]);
                
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
        case CREATE_NAME_OF_THE_TAB:
        {
            if (strlen(args) < 2)
            {
                show_create_database(id);
                return PLUGIN_HANDLED;
            }
            
            if (!isalpha(args[0]))
            {
                show_create_column(id);
                chat_color(id, "%s !yOnly alphabetic characters.", SZPREFIX);
                return PLUGIN_HANDLED;
            }
            
            if (g_database_exists)
            {
                if (sqlite_TableExists(g_sql_connection, args))
                {
                    chat_color(id, "%s !yA table with the name already exists !g%s!y.", SZPREFIX, args);
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
        case NAME_OF_THE_TAB:
        {
            if (strlen(args) < 2)
            {
                show_create_column(id);
                return PLUGIN_HANDLED;
            }
            
            if (!isalpha(args[0]))
            {
                show_create_column(id);
                chat_color(id, "%s !yOnly alphabetic characters.", SZPREFIX);
                return PLUGIN_HANDLED;
            }
            
            if (!g_change[id])
            {
                chat_color(id, "%s !yThere is no way to add columns activated.", SZPREFIX);
                return PLUGIN_HANDLED;
            }
            
            if (g_database_exists)
            {
                if (!sqlite_TableExists(g_sql_connection, args))
                {
                    chat_color(id, "%s !yThe !g%s!y table does not exist in the database.", SZPREFIX, args);
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
        case NAME_OF_THE_COLUMN:
        {
            if (strlen(args) < 2)
            {
                show_create_column(id);        
                return PLUGIN_HANDLED;
            }
            
            if (!isalpha(args[0]))
            {
                show_create_column(id);
                chat_color(id, "%s !yOnly alphabetic characters.", SZPREFIX);
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
                    chat_color(id, "%s !yA column with !g%s!y name already exists.", SZPREFIX, args);
                    SQL_FreeHandle(query);
                }
            }
            
            show_create_column(id);
        }
        case VALUE_OF_THE_COLUMN: 
        {
            if (!g_change[id])
                copy(g_column[(g_column_edit[id] == 1) ? g_column_selected[id] : g_column_create[id]][COLUMN_VALUE], 31, args);
            else
                copy(g_column[g_column_change[id]][COLUMN_VALUE], 31, args);
            show_create_column(id);
        }
        case SELECT_TABLE:
        {
            if (!sqlite_TableExists(g_sql_connection, args))
            { 
                chat_color(id, "%s !yThe !g%s!y table does not exist in the database.", SZPREFIX, args);
                show_edit_column(id);
                return PLUGIN_HANDLED;
            }
            
            copy(g_table_view[id], 31, args);
            show_edit_column(id);
        }
        case SELECT_COLUMN:
        {
            if (strlen(args) < 2)
            {
                chat_color(id, "%s !yThe value is incorrect.", SZPREFIX, args);
                clcmd_table(id);
                return PLUGIN_HANDLED;
            }
            
            new Handle:query;
            query = SQL_PrepareQuery(g_sql_connection, "SELECT %s FROM '%s'", args, g_table_view[id]);
            
            if (!SQL_Execute(query))
            {
                chat_color(id, "%s !yThe !g%s!y column does not exist in the table.", SZPREFIX, args);
                show_edit_column(id);
                SQL_FreeHandle(query);
                return PLUGIN_HANDLED;
            }
            else
                SQL_FreeHandle(query);
            
            copy(g_column_view[id], 31, args);
            show_edit_column(id);
        }
        case SELECT_VALUE:
        {
            if (!strlen(args))
            {
                chat_color(id, "%s !yYou can not leave the field empty.", SZPREFIX, args);
                show_edit_column(id);
                return PLUGIN_HANDLED;
            }
            
            copy(g_value_view[id], 31, args);
            show_edit_column(id);
        }
        case DELETE_TABLE:
        {
            if (!strlen(args))
            {
                chat_color(id, "%s !yYou can not leave the field empty.", SZPREFIX, args);
                show_menu(id, (1<<0)|(1<<1)|(1<<9), "\yDelete table / column^n^n\r1. \wTable^n\r2. \dColumn^n^n^n\r0. \wGo back", -1, "Show Delete Function");
                return PLUGIN_HANDLED;
            }
            
            if (!sqlite_TableExists(g_sql_connection, args))
            { 
                chat_color(id, "%s !yThe !g%s!y table does not exist in the database.", SZPREFIX, args);
                show_menu(id, (1<<0)|(1<<1)|(1<<9), "\yDelete table / column^n^n\r1. \wTable^n\r2. \dColumn^n^n^n\r0. \wGo back", -1, "Show Delete Function");
                return PLUGIN_HANDLED;
            }
            
            new Handle:query;
            query = SQL_PrepareQuery(g_sql_connection, "DROP TABLE '%s'", args);
            
            if (!SQL_Execute(query))
                sql_query_error(query, id);
            else
            {
                chat_color(id, "%s !yThe !g%s!y table was removed from the database.", SZPREFIX, args);
                SQL_FreeHandle(query);
            }
            
            show_menu(id, (1<<0)|(1<<1)|(1<<9), "\yDelete table / column^n^n\r1. \wTable^n\r2. \dColumn^n^n^n\r0. \wGo back", -1, "Show Delete Function");
        }
        case ADD_COLUMN:
        {
            if (strlen(args) < 2)
            {
                show_edit_type_column(id);        
                return PLUGIN_HANDLED;
            }
            
            if (!isalpha(args[0]))
            {
                show_edit_type_column(id);
                chat_color(id, "%s !yOnly alphabetic characters.", SZPREFIX);
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
    
    len += formatex(menu[len], charsmax(menu) - len, "\yCreate database^n^n\r1. \wName of the table: \y%s^n^n\r2. %sCreate a column^n^n^n\r0. \wGo back", g_table, (strlen(g_table) > 0) ? "\w" : "\d");
    
    show_menu(id, (1<<0)|(1<<1)|(1<<9), menu, -1, "Show Create Database");
    
    return PLUGIN_HANDLED;
}

public handled_show_create_database(id, key)
{
    switch(key)
    {
        case 0: g_change[id] = 0, client_cmd(id, "messagemode CREATE_NAME_OF_THE_TAB"), g_messagemode[id] = CREATE_NAME_OF_THE_TAB;
        case 1: 
        {
            if (strlen(g_table) > 0)
                show_create_column(id);
            else
            {
                chat_color(id, "%s !yYou have to put the name of the table before creating a column.", SZPREFIX); 
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
            
            formatex(table, 31, "* \dName of the table: \y-", g_table_view[id]);
            copy(tittle, 31, "Edit created columns");
            copy(edit, 31, "Edit the created column");
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
            
            formatex(table, 31, "* \dName of the table: \y-", g_table_view[id]);
            copy(tittle, 31, "Create column");
            copy(edit, 31, "Create the column");
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
        
        formatex(table, 31, "* \wName of the table: \y%s", g_table_view[id]);
        copy(tittle, 31, "Add columns");
        copy(edit, 31, "Add column to the table");
    }
    
    len += formatex(menu[len], charsmax(menu) - len, "\y%s^n^n%s^n\r* \wName of the column: \y%s^n\r* \yType: \d%s^n\r* %sValue: \y%s^n^n\r* \yValue assignment: \r%s^n^n\r* %sPrimary Key^n\r* %sAutoincrement^n\r* %sUnique^n^n\r9. \w%s^n\r0. \wGo back", 
    tittle, table, column, type, cvalue, (type_column) ? value : "ANY", ((type_column)) ? "Yes" : "No", primary_key, autoincrement, unique, edit);
    
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
                chat_color(id, "%s !yThis is only available to create columns in a table.", SZPREFIX);
                show_create_column(id);
                return PLUGIN_HANDLED;
            }
            
            client_cmd(id, "messagemode NAME_OF_THE_TAB"), g_messagemode[id] = NAME_OF_THE_TAB;
        }
        case 1: client_cmd(id, "messagemode NAME_OF_THE_COLUMN"), g_messagemode[id] = NAME_OF_THE_COLUMN;
        case 2: 
        {
            show_column_type(id); 
            return PLUGIN_HANDLED;
        }
        case 3: client_cmd(id, "messagemode VALUE_OF_THE_COLUMN"), g_messagemode[id] = VALUE_OF_THE_COLUMN;
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
                    client_print(id, print_center, "The %s column was modified", g_column[g_column_selected[id]][COLUMN_NAME]);
                    show_edit_database(id);
                    return PLUGIN_HANDLED;
                }
                
                if (!strlen(g_column[g_column_create[id]][COLUMN_TYPE]))
                {
                    show_create_column(id);
                    chat_color(id, "%s !yYou have to select the type of column you want to create.", SZPREFIX);
                    return PLUGIN_HANDLED;
                }
                
                g_column_create[id]++;
                copy(g_column_edit[g_column_create[id]], 31, g_column[g_column_create[id]][COLUMN_NAME]);
                client_print(id, print_center, "The %s column was created successfully", g_column[g_column_create[id]][COLUMN_NAME]);
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
                    chat_color(id, "%s !yColumn created.", SZPREFIX);
                    chat_color(id, "%s !yName: !g%s!y - Table: !g%s!y.", SZPREFIX, g_column[g_column_change[id]][COLUMN_NAME], g_table_view[id]);
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
        client_print(id, print_center, "THE TABLE WAS CREATED WITH SUCCESS");
        
        if (!g_database_exists)
        {
            chat_color(id, "%s !yA database with the name !g%s!y was created.", SZPREFIX, SQL_DATABASE);
            chat_color(id, "%s !yFile: !g%s!y - Name of the table: !g%s!y - Columns: !g%d / %d!y.", SZPREFIX, SQL_DATABASE, g_table, g_column_create[id], MAX_COLUMNS);
            chat_color(id, "%s !yVer consola para ver la consulta.", SZPREFIX);
        }
        else
        {
            chat_color(id, "%s !yThe table was created successfully.", SZPREFIX);
            chat_color(id, "%s !yFile: !g%s!y - Name of the table: !g%s!y - Columns: !g%d / %d!y.", SZPREFIX, SQL_DATABASE, g_table, g_column_create[id], MAX_COLUMNS);
            chat_color(id, "%s !ySee console to see the query.", SZPREFIX);
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
    g_messagemode[id] = CREATE_NAME_OF_THE_TAB;
}

sql_query_error(Handle:query, id)
{
    static error[56];
    SQL_QueryError(query, error, 55);
        
    chat_color(id, "%s !yQuery Error: !g%s!y.", SZPREFIX, error);
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