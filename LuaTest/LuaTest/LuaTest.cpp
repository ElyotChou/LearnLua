// LuaTest.cpp : This file contains the 'main' function. Program execution begins and ends there.
//

#include <iostream>
#include <string.h>
extern "C"
{
#include "Lua/lua.h"
#include "Lua/lauxlib.h"
#include "Lua/lualib.h"
}

static void stackDump(lua_State *L)
{
	int i;
	int top = lua_gettop(L);

	for (i = 1; i <= top; i++)
	{
		int t = lua_type(L, i);

		switch (t)
		{
		case LUA_TSTRING:
			printf("'%s'", lua_tostring(L, i));
			break;
		case LUA_TBOOLEAN:
			printf(lua_toboolean(L, i) ? "true" : "false");
			break;
		case LUA_TNUMBER:
			if (lua_isinteger(L, i))
			{
				printf("%lld", lua_tonumber(L, i));
			}
			else
			{
				printf("%g", lua_tonumber(L, i));
			}
			break;
		default:
			printf("%s", lua_typename(L, i));
			break;
		}

		printf("   ");
	}

	printf("\n");
}

int main()
{
	char buff[256];
	int err;

	lua_State* L = luaL_newstate();
	luaL_openlibs(L);

	//while (fgets(buff,sizeof(buff),stdin) != NULL)
	//{
	//	err = luaL_dofile(L, "Test.lua");
	//	if (err)
	//	{
	//		fprintf(stderr,"%s\n",lua_tostring(L,-1));
	//		lua_pop(L, 1);
	//	}
	//}

	lua_pushboolean(L, 1);
	lua_pushnumber(L, 10);
	lua_pushnil(L);
	lua_pushstring(L, "Hello");
	stackDump(L);

	lua_pushvalue(L, -1); 	stackDump(L);

	lua_replace(L, 2); stackDump(L);

	lua_rotate(L, 2, -1); stackDump(L);


	int stackNum = lua_gettop(L);

	printf("%d", stackNum);

	lua_close(L);
	getchar();

	return 0;
}

// Run program: Ctrl + F5 or Debug > Start Without Debugging menu
// Debug program: F5 or Debug > Start Debugging menu

// Tips for Getting Started: 
//   1. Use the Solution Explorer window to add/manage files
//   2. Use the Team Explorer window to connect to source control
//   3. Use the Output window to see build output and other messages
//   4. Use the Error List window to view errors
//   5. Go to Project > Add New Item to create new code files, or Project > Add Existing Item to add existing code files to the project
//   6. In the future, to open this project again, go to File > Open > Project and select the .sln file
