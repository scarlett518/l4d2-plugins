#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define PLUGIN_VERSION	"1.0"
#define PLUGIN_NAME		"l4d2_SurvivorDeathCheck"

ConVar C_DeathCheckSwitch, C_DeathCheckOption;

bool B_DeathCheckSwitch;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "X光",
	description = "幸存者全部死亡才算结束",
	version = PLUGIN_VERSION,
	url = "QQ群59046067"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_sw", Command_DeathSwitch, ADMFLAG_KICK, "插件开关指令");
	CreateConVar("l4d2_SurvivorDeathCheck", PLUGIN_VERSION, "survivor death check plugin version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	C_DeathCheckSwitch = CreateConVar("l4d2_SurvivorDeathCheck_death_check_switch", "1", "插件开关(指令 !sw 关闭或开启插件). 0=禁用, 1=启用.", FCVAR_NOTIFY);
	C_DeathCheckOption = FindConVar("director_no_death_check");
	C_DeathCheckSwitch.AddChangeHook(ConVar_Changed);

	HookEvent("player_incapacitated", Event_PlayerIncapacitated);	//玩家倒地事件.
	HookEvent("player_death", EventPlayerDeath);					//玩家死亡事件.
	HookEvent("mission_lost", Event_MissionLost);					//任务失败事件.

	//AutoExecConfig(true, "mission_wont_fail_till_all_survivor_died");
}

void get_cvars()
{
	B_DeathCheckSwitch = C_DeathCheckSwitch.BoolValue;

	if (!B_DeathCheckSwitch)
	{
		C_DeathCheckOption.BoolValue = false;
	}
}

void ConVar_Changed(ConVar convar, const char[] oldValue, const char[] newValue)
{
	get_cvars();
}

public void OnConfigsExecuted()
{
	get_cvars();
}

public Action Command_DeathSwitch(int client, int args)
{
	if (B_DeathCheckSwitch)
	{
		C_DeathCheckSwitch.BoolValue = false;
		C_DeathCheckOption.BoolValue = false;
		PrintToChat(client, "\x04[提示]\x05全部死亡才算结束已\x03关闭\x05.");
	}
	else
	{
		C_DeathCheckSwitch.BoolValue = true;
		C_DeathCheckOption.BoolValue = true;
		PrintToChat(client, "\x04[提示]\x05全部死亡才算结束已\x03开启\x05.");
	}
	return Plugin_Handled;
}

//玩家倒地事件.
void Event_PlayerIncapacitated(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!B_DeathCheckSwitch)
		return;

	if (client > 0 && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
	{
		C_DeathCheckOption.BoolValue = true;
	}
}

//玩家死亡事件.
void EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!B_DeathCheckSwitch)
		return;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
		{
			C_DeathCheckOption.BoolValue = true;
			return;
		}
		else
		{
			C_DeathCheckOption.BoolValue = false;
		}
	}
}

//任务失败事件.
void Event_MissionLost(Event event, const char[] name, bool dontBroadcast)
{
	if (!B_DeathCheckSwitch)
		return;

	C_DeathCheckOption.BoolValue = true;
}