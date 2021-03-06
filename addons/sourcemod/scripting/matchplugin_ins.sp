#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <colors>
#include <sdkhooks>
#include <textparse>

#include <matchplugin_ins>


public Plugin:myinfo ={
	name = "Match Plugin Insurgency",
	author = "Aphex <steamfor@gmail.com>",
	description = "Match Server Plugin for Insurgency",
	version = "2.0.2",
	url = "http://www.sourcemod.net/"
};



new MPINS_MatchStatus:g_match_status = MPINS_MatchStatus:NONE;
new MPINS_MatchStatus:g_new_match_status;
new Handle:FWD_OnMatchStatusChange;
new Handle:FWD_OnChatCmd;
new Handle:FWD_OnHelpCalled;
new Handle:FWD_OnTeamReady;
new Handle:FWD_OnTeamUnready;
new Handle:FWD_OnAllTeamsReady;


new Menu:g_voting_menu;
new String:g_voting_name[64];
new String:g_voting_tittle[64];
new String:g_voting_descr[64];
new Float:g_voting_cNextvote[MAXPLAYERS+1];


new g_team_player_cnt[TEAM];
new g_player_cnt;
new g_team_player_limit[TEAM];

new String:g_chat_command_prefix[32] = "##";
new Handle:g_maplist;


new StringMap:g_cmds;		//"cmd_alias" -> "fn_name"
new StringMap:g_cmds_fn;	//"fn_name" -> "plugin_handler"
new StringMap:g_votes;
new StringMap:g_votes_fn;
new Handle:g_voting_fn_plugin;
new String:g_voting_fn_name[128];

new bool:g_is_waiting_rdy;
new bool:g_teams_rdy[TEAM];
new String:g_rdy_for[64];
new String:g_rdy_descr[256];

new StringMap:g_configs;
new String:g_curcfg[32];
new bool:g_SMC_configs_sec = false;

new String:g_hostname[128];
new ConVar:CVAR_hostname;
new ConVar:CVAR_sv_password;

new ConVar:CVAR_matchplugin_cmd_prefix;
new ConVar:CVAR_matchplugin_welcome;
new ConVar:CVAR_matchplugin_hostname_status;
new ConVar:CVAR_matchplugin_hostname_showpw;
new ConVar:CVAR_matchplugin_hostname_showcfg;
new ConVar:CVAR_matchplugin_disable_kill_cmd;
new ConVar:CVAR_matchplugin_forbid_team_change;
new ConVar:CVAR_matchplugin_generate_pw;
new ConVar:CVAR_matchplugin_vote_cooldown;
new ConVar:CVAR_matchplugin_use_maplist;


new const String:sig_WaitingForMatchStart[] = "match_start";
new const String:sig_WaitingForMatchStart_descr[] = "match start";

new const Float:Hibernation_enable_timeout = 15.0;


public OnPluginStart(){
	InitPlugin();
}
public OnPluginEnd(){
	TeardownPlugin();
}
public OnMapStart(){
	Set_sv_hibernate_when_empty(0);
	CVAR_hostname.GetString(g_hostname, sizeof(g_hostname));
	MPINS_Native_SetMatchStatus(MPINS_MatchStatus:WAITING);
	CreateTimer(Hibernation_enable_timeout, Timer_sv_hibernate_when_empty, 1);
}
public OnConfigsExecuted(){
	new maplist_serial = -1;
	ReadMapList(g_maplist, maplist_serial, "default", MAPLIST_FLAG_CLEARARRAY);
	if(CVAR_matchplugin_disable_kill_cmd.BoolValue)
		disable_kill_cmd();
	on_match_waiting_post();
}


public OnClientPutInServer(client){
	g_player_cnt++;
	player_welcome(client);
}

public OnClientDisconnect(client){
	if(!IsClientInGame(client))
		return;
	new TEAM:team = TEAM:GetClientTeam(client);
	g_player_cnt--;
	g_team_player_cnt[team]--;
	if(g_player_cnt < 1){
		MPINS_Native_SetMatchStatus(WAITING);
	}
	CreateTimer(1.0, Timer_check_players);
}
public InitPlugin(){
	Set_sv_hibernate_when_empty(0); // Hibernation breaks server initialization sequence
	InitCVARs();
	InitVars();
	InitCMDs();
	InitHooks();
	load_config_file("configs/match_plugin.txt");
	exec_config(g_curcfg);
	CreateTimer(Hibernation_enable_timeout, Timer_sv_hibernate_when_empty, 1);
}
public TeardownPlugin(){
	RemoveCVARs();
	RemoveCMDs();
	RemoveHooks();
}



public InitVars(){
	new Handle:ch = GetMyHandle();
	g_maplist = CreateArray(48);
	g_configs = new StringMap();

	g_cmds = new StringMap();
	g_cmds_fn = new StringMap();
	g_votes = new StringMap();
	g_votes_fn = new StringMap();


	MPINS_Native_RegCmd("help",				"cmd_fn_help", ch);
	MPINS_Native_RegCmd("h",				"cmd_fn_help", ch);
	MPINS_Native_RegCmd("start",			"cmd_fn_start", ch);
	MPINS_Native_RegCmd("e",				"cmd_fn_execcfg", ch);
	MPINS_Native_RegCmd("exec",				"cmd_fn_execcfg", ch);
	MPINS_Native_RegCmd("execcfg",			"cmd_fn_execcfg", ch);
	MPINS_Native_RegCmd("r",				"cmd_fn_ready", ch);
	MPINS_Native_RegCmd("ready",			"cmd_fn_ready", ch);
	MPINS_Native_RegCmd("nr",				"cmd_fn_notready", ch);
	MPINS_Native_RegCmd("notready",			"cmd_fn_notready", ch);
	MPINS_Native_RegCmd("stop",				"cmd_fn_stop", ch);
	MPINS_Native_RegCmd("cm",				"cmd_fn_changemap", ch);
	MPINS_Native_RegCmd("map",				"cmd_fn_changemap", ch);
	MPINS_Native_RegCmd("nm",				"cmd_fn_nextmap", ch);
	MPINS_Native_RegCmd("nextmap",			"cmd_fn_nextmap", ch);
	MPINS_Native_RegCmd("rr",				"cmd_fn_restartround", ch);
	MPINS_Native_RegCmd("restartround",		"cmd_fn_restartround", ch);
	MPINS_Native_RegCmd("rg",				"cmd_fn_restartgame", ch);
	MPINS_Native_RegCmd("restartgame",		"cmd_fn_restartgame", ch);
	MPINS_Native_RegCmd("st",				"cmd_fn_switchteams", ch);
	MPINS_Native_RegCmd("switchteams",		"cmd_fn_switchteams", ch);
	MPINS_Native_RegCmd("pw",				"cmd_fn_showpassword", ch);
	MPINS_Native_RegCmd("password",			"cmd_fn_showpassword", ch);
	MPINS_Native_RegCmd("status",			"cmd_fn_status", ch);
	MPINS_Native_RegCmd("lc",				"cmd_fn_listcfg", ch);
	MPINS_Native_RegCmd("listcfg",			"cmd_fn_listcfg", ch);
	MPINS_Native_RegCmd("listconfig",		"cmd_fn_listcfg", ch);
	MPINS_Native_RegCmd("ks",				"cmd_fn_kickspectators", ch);
	MPINS_Native_RegCmd("kickspectators",	"cmd_fn_kickspectators", ch);


	MPINS_Native_RegVote("vote_match_stop",		"VoteHandler_match_stop", ch);
	MPINS_Native_RegVote("vote_restart_round",	"VoteHandler_restart_round", ch);
	MPINS_Native_RegVote("vote_restart_game",	"VoteHandler_restart_game", ch);
	MPINS_Native_RegVote("vote_switch_teams",	"VoteHandler_switch_teams", ch);
	CVAR_hostname.GetString(g_hostname, sizeof(g_hostname));
}

public InitCVARs(){
	CVAR_matchplugin_cmd_prefix =				CreateConVar("sm_matchplugin_cmd_prefix",			g_chat_command_prefix,	"Chat command prefix");
	CVAR_matchplugin_welcome =					CreateConVar("sm_matchplugin_welcome",				"1",					"Enable player welcome message");
	CVAR_matchplugin_hostname_status =			CreateConVar("sm_matchplugin_hostname_status",		"1",					"Enables displaying server status at hostname tail");
	CVAR_matchplugin_hostname_showpw = 			CreateConVar("sm_matchplugin_hostname_showpw",		"1",					"Enables displaying default server password while match not running");
	CVAR_matchplugin_hostname_showcfg = 		CreateConVar("sm_matchplugin_hostname_showcfg",		"1",					"Enables displaying current matchplugin config loaded");
	CVAR_matchplugin_disable_kill_cmd =			CreateConVar("sm_matchplugin_disable_kill_cmd",		"1",					"Disable 'kill' cmd for players");
	CVAR_matchplugin_forbid_team_change =		CreateConVar("sm_matchplugin_forbid_team_change",	"1",					"Forbid players from changing team while match is running");
	CVAR_matchplugin_generate_pw = 				CreateConVar("sm_matchplugin_generate_pw",			"1",					"Randomly generate password on match start");
	CVAR_matchplugin_vote_cooldown =			CreateConVar("sm_matchplugin_vote_cooldown",		"30",					"Cooldown in seconds between player votes");
	CVAR_matchplugin_use_maplist = 				CreateConVar("sm_matchplugin_use_maplist",			"0",					"Only use maps from maplist");

	CVAR_hostname = FindConVar("hostname");
	CVAR_sv_password = FindConVar("sv_password");

	AutoExecConfig(true);
	CVAR_matchplugin_cmd_prefix.AddChangeHook(OnChange_CVAR_matchplugin_cmd_prefix);
	CVAR_matchplugin_disable_kill_cmd.AddChangeHook(OnChange_CVAR_matchplugin_disable_kill_cmd);
}
public RemoveCVARs(){
	CVAR_matchplugin_cmd_prefix.RemoveChangeHook(OnChange_CVAR_matchplugin_cmd_prefix);
	CVAR_matchplugin_disable_kill_cmd.RemoveChangeHook(OnChange_CVAR_matchplugin_disable_kill_cmd);
}

public InitCMDs(){
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_Say);
}
public RemoveCMDs(){
	SetCommandFlags("kill", GetCommandFlags("kill") & ~(FCVAR_CHEAT));
}

public InitHooks(){
	HookEvent("game_start", GameEvents_GameStart);
	HookEvent("game_end", GameEvents_GameEnd);
	HookEvent("round_start", GameEvents_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", GameEvents_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_team", GameEvents_player_team, EventHookMode_Pre);
	AddCommandListener(Command_jointeam, "jointeam");
	AddCommandListener(Command_spectate, "spectate");
}
public RemoveHooks(){
	UnhookEvent("game_start", GameEvents_GameStart);
	UnhookEvent("game_end", GameEvents_GameEnd);
	UnhookEvent("round_start", GameEvents_RoundStart, EventHookMode_PostNoCopy);
	UnhookEvent("round_end", GameEvents_RoundEnd, EventHookMode_PostNoCopy);
	UnhookEvent("player_team", GameEvents_player_team, EventHookMode_Pre);
	RemoveCommandListener(Command_jointeam, "jointeam");
	RemoveCommandListener(Command_spectate, "spectate");
}




/*
 * CVARS Hooks
 */
public OnChange_CVAR_matchplugin_cmd_prefix(ConVar:convar, const String:oldValue[], const String:newValue[]){
	strcopy(g_chat_command_prefix, sizeof(g_chat_command_prefix), newValue);
	SetConVarString(convar, g_chat_command_prefix);
}
public OnChange_CVAR_matchplugin_disable_kill_cmd(ConVar:convar, const String:oldValue[], const String:newValue[]){
	new disable_kill = convar.BoolValue;
	if(disable_kill)
		disable_kill_cmd();
	else
		enable_kill_cmd();
}
disable_kill_cmd(){
	SetCommandFlags("kill", GetCommandFlags("kill") | FCVAR_CHEAT);
}
enable_kill_cmd(){
	SetCommandFlags("kill", GetCommandFlags("kill") & ~(FCVAR_CHEAT));
}





/*
 * Game Events
 */
public Action:GameEvents_GameStart(Handle:event, const String:name[], bool:dontBroadcast){
	return Plugin_Continue;
}
public Action:GameEvents_GameEnd(Handle:event, const String:name[], bool:dontBroadcast){
	MPINS_Native_SetMatchStatus(MPINS_MatchStatus:ENDED);
	return Plugin_Continue;
}
public GameEvents_RoundStart(Handle:event, const String:name[], bool:dontBroadcast){
	if(g_match_status == MPINS_MatchStatus:LIVE_ON_RESTART){
		MPINS_Native_SetMatchStatus(MPINS_MatchStatus:LIVE);
	}
}
public GameEvents_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast){

}
public Action:GameEvents_player_team(Handle:event, const String:name[], bool:dontBroadcast){
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new TEAM:oldteam = TEAM:GetEventInt(event, "oldteam");
	new TEAM:team = TEAM:GetEventInt(event, "team");

	g_team_player_cnt[team]++;
	if(oldteam){
		g_team_player_cnt[oldteam]--;
	}
	CreateTimer(1.0, Timer_check_players);
	if(!oldteam){
		if(team == TEAM:SPECTATORS){
			return Plugin_Continue;
		}
		ChangeClientTeam(client, view_as<int>(TEAM:SPECTATORS));
		return Plugin_Handled;
	}
	return Plugin_Continue;
}



public Action:Command_jointeam(client, const char[] command, int argc){
	if(argc < 1)
		return Plugin_Handled;
	if(!IsValidClient(client) || IsFakeClient(client))
		return Plugin_Continue;

	char arg[4];
	GetCmdArg(1, arg, sizeof(arg));
	new TEAM:new_team = TEAM:StringToInt(arg);
	new TEAM:cur_team = TEAM:GetClientTeam(client);
   	if(new_team == TEAM:NONE){
		if(cur_team == TEAM:NONE){
			ChangeClientTeam(client, view_as<int>(TEAM:SPECTATORS));
		}
		return Plugin_Handled;
	}
	if(g_match_status == WAITING)
		return Plugin_Continue;
	if(!CVAR_matchplugin_forbid_team_change.BoolValue)
		return Plugin_Continue;
   	if(cur_team == SPECTATORS){// || cur_team == TEAM:NONE){
		if(g_team_player_cnt[new_team] < g_team_player_limit[new_team]){
			return Plugin_Continue;
		}
		return Plugin_Handled;
	}else{
		ReplyToCommand(client, "Team switching is restricted while match is running");
		return Plugin_Handled;
	}
}
public Action:Command_spectate(client, const char[] command, int argc){
	if(g_match_status == WAITING)
		return Plugin_Continue;
	if(!CVAR_matchplugin_forbid_team_change.BoolValue)
		return Plugin_Continue;
	ReplyToCommand(client, "Team switching is restricted while match is running");
	return Plugin_Handled;
}






public Action:map_advance(){
	new String:map[64];
	new Handle:nextmap = FindConVar("nextlevel");
	if(nextmap != INVALID_HANDLE){
		GetConVarString(nextmap, map, sizeof(map));
		if(!StrEqual(map, "") && IsMapValid(map)){
			ServerCommand("changelevel \"%s\"", map);
		}else{
			GetCurrentMap(map, sizeof(map));
		}
	}else{
		GetCurrentMap(map, sizeof(map));
	}
	ServerCommand("changelevel \"%s\"", map);
	ServerExecute();
}




public Action:Command_Say(client, args){
	if (client <= 0 || client > MaxClients)
		return Plugin_Continue;
	new String:message[512];
	GetCmdArgString(message, sizeof(message));
	StripQuotes(message);
	TrimString(message);

	new Action:act;
	MPINS_Native_ChatCmd(client, message, act);
	if(act == Plugin_Continue)
		return Plugin_Continue;
	return Plugin_Handled;
}


public Action:MPINS_OnChatCmd(client, const String:message[]){
	decl String:args[6][64];
	new args_cnt;
	new i,si;
	for(; args_cnt<6;args_cnt++){
		si = BreakString(message[i], args[args_cnt], sizeof(args[]));
		if(si == -1) break;
		i += si;
	}
	if(strcmp(args[0], g_chat_command_prefix) != 0){
		return Plugin_Continue;
	}
	new ArrayList:largs = new ArrayList(64);
	for(i=0;i<=args_cnt;i++){
		largs.PushString(args[i]);
	}
	new TEAM:team = TEAM:GetClientTeam(client);
	if(args_cnt < 1){
		cmd_fn_help(client, largs);
		return Plugin_Handled;
	}
	if(team == TEAM:SPECTATORS){ // FIXME
		return Plugin_Continue;
	}

	new String:buf_fn_name[64];
	if(g_cmds.GetString(args[1], buf_fn_name, sizeof(buf_fn_name))){
		new Handle:buf_fn_plugin;
		if(g_cmds_fn.GetValue(buf_fn_name, buf_fn_plugin)){
			new Function:cmd_fn = Function:GetFunctionByName(buf_fn_plugin, buf_fn_name);
			Call_StartFunction(buf_fn_plugin, cmd_fn);
			Call_PushCell(client);
			Call_PushCell(largs);
			Call_Finish();
		}else{
			PrintToChat(client, "[%s] ERROR", CHAT_PFX);
		}
	}else{
		PrintToChat(client, "[%s] Unknown command\nTry \"%s help\" for command list.", CHAT_PFX, g_chat_command_prefix);
	}
	delete largs;
	return Plugin_Handled;
}




public Action:MPINS_OnMatchStatusChange(MPINS_MatchStatus:old_status, &MPINS_MatchStatus:new_status){
	if(g_new_match_status != MPINS_MatchStatus:NONE){
		new_status = g_new_match_status;
		g_new_match_status = MPINS_MatchStatus:NONE;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public on_match_waiting(){
	InsertServerCommand("exec server.cfg");
	ServerExecute();
	exec_config(g_curcfg);
	MPINS_Native_SetWaitForReadiness(sig_WaitingForMatchStart, sig_WaitingForMatchStart_descr);
	on_match_waiting_post();
}
public on_match_waiting_post(){
	warmup_start();
	SetIdlingHostname();
}

public on_match_starting(){
	g_team_player_limit[INSURGENTS] = g_team_player_cnt[INSURGENTS];
	g_team_player_limit[SECURITY] = g_team_player_cnt[SECURITY];
	warmup_end();
	UpdateHostnamePostfix("LIVE");
	if(CVAR_matchplugin_generate_pw.BoolValue){
		new String:passwd[5];
		new passwd_r = GetRandomInt(1000, 9999);
		IntToString(passwd_r, passwd, sizeof(passwd));
		CVAR_sv_password.SetString(passwd);
	}
	CreateTimer(1.0, start_stage_1);
}

public on_match_live_on_restart(){
	InsertServerCommand("mp_restartgame 1");
	ServerExecute();
}


public on_match_live(){
	CPrintToChatAll("{green}%s","=>|GL|--!LIVE!--|HF|<=");
}

public on_match_stoping(){
	CPrintToChatAll("[%s] {green}Stopping match...", CHAT_PFX);
	InsertServerCommand("mp_restartgame 1");
	ServerExecute();
	MPINS_Native_SetMatchStatus(WAITING);
}

public on_match_ended(){

}


warmup_start(){
	InsertServerCommand("mp_minteamplayers 50");
	InsertServerCommand("mp_joinwaittime 100000");
	ServerExecute();
}
warmup_end(){
	InsertServerCommand("mp_minteamplayers 1");
	InsertServerCommand("mp_joinwaittime 1");
	ServerExecute();
}







/*
 *	Configs
 */

public load_config_file(String:configFile[]){
	new String:configFilePath[100] = "";
	BuildPath(Path_SM, configFilePath, sizeof(configFilePath), configFile);
	if(!FileExists(configFilePath)){
		create_default_config_file(configFilePath);
		if (!FileExists(configFilePath)){
			SetFailState("Config file '%s' not found.", configFilePath);
		}
	}
	g_configs.Clear();

	new SMCParser:SMC_configs = new SMCParser();
	SMC_configs.OnEnterSection = configs_read_NewSection;
	SMC_configs.OnKeyValue = configs_read_KeyValue;
	SMC_configs.OnLeaveSection = configs_read_EndSection;

	new SMCError:err = SMC_configs.ParseFile(configFilePath);
	if(err != SMCError_Okay){
		char buffer[64];
		if(SMC_configs.GetErrorString(err, buffer, sizeof(buffer))){
			PrintToServer("%s", buffer);
		}else{
			PrintToServer("Fatal parse error");
		}
	}
}
public SMCResult configs_read_NewSection(SMCParser smc, const char[] name, bool opt_quotes){
	if(StrEqual(name, "configs")){
		g_SMC_configs_sec = true;
	}
	return SMCParse_Continue;
}
public SMCResult configs_read_KeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes){
	if(g_SMC_configs_sec){
		g_configs.SetString(key, value);
	}
	return SMCParse_Continue;
}
public SMCResult configs_read_EndSection(SMCParser smc){
	g_SMC_configs_sec = false;
	return SMCParse_Continue;
}

public create_default_config_file(String:configFilePath[]){
	new Handle:kv_configs = CreateKeyValues("configs");

	KvJumpToKey(kv_configs, "configs", true);
	KvSetString(kv_configs, "default", "server.cfg");

	KvRewind(kv_configs);
	KeyValuesToFile(kv_configs, configFilePath);
	CloseHandle(kv_configs);
}

public exec_config(String:cfgName[32]){
	if(StrEqual(cfgName, "")){
		new StringMapSnapshot:keys = g_configs.Snapshot();
		keys.GetKey(0, cfgName, sizeof(cfgName));
	}
	new String:cfgFile[127];
	if(g_configs.GetString(cfgName, cfgFile, sizeof(cfgFile))){
		InsertServerCommand("exec %s", cfgFile);
		ServerExecute();
		tag_append("pms");
		return true;
	}
	return false;
}





/*
 * FN
 */
public cmd_fn_start(client, ArrayList:m_args){
	if(!IsGenericAdmin(client)){
		PrintToChat(client, "[%s] You do not have access to this command", CHAT_PFX);
		return;
	}
	if(g_match_status != WAITING){
		PrintToChat(client, "[%s] Game already started!", CHAT_PFX);
		return;
	}
	MPINS_Native_UnsetWaitForReadiness(sig_WaitingForMatchStart);
	MPINS_Native_SetMatchStatus(STARTING);
	return;
}

public cmd_fn_stop(client, ArrayList:m_args){
	if(!(g_match_status == LIVE || g_match_status == MODULE_HANDLED)){
		PrintToChat(client, "[%s] Game not running.", CHAT_PFX);
		return;
	}
	MPINS_Native_VoteStart(client, "vote_match_stop", "Stop the match?", "match stop");
	return;
}

public cmd_fn_changemap(client, ArrayList:m_args){
	if(g_match_status != WAITING && g_match_status != ENDED){
		PrintToChat(client, "[%s] Map can't be changed while match is running", CHAT_PFX);
		return;
	}
	if(m_args.Length < 3){
		PrintToChat(client, "[%s] Specify map name", CHAT_PFX);
		return;
	}
   	new String:s_map[32];
	m_args.GetString(2, s_map, sizeof(s_map));
	if(!CVAR_matchplugin_use_maplist.BoolValue){
		changemap(s_map);
		return;
	}
	new map_cnt = GetArraySize(g_maplist);
	decl String:c_map[32];
	for (new i = 0; i < map_cnt; i++){
		GetArrayString(g_maplist, i, c_map, sizeof(c_map));
		if(StrEqual(c_map, s_map, false)){
			changemap(s_map);
			return;
		}
	}
	PrintToChat(client, "[%s] Map '%s' not found", CHAT_PFX, s_map);
}

changemap(String:map[]){
	if(!IsMapValid(map))
	    return;
	InsertServerCommand("sm_nextmap \"%s\"", map);
	InsertServerCommand("nextlevel \"%s\"", map);
	InsertServerCommand("sm_map \"%s\"", map);
	ServerExecute();
}


public cmd_fn_nextmap(client, ArrayList:m_args){
	if(m_args.Length < 3){
		PrintToChat(client, "[%s] Specify map name", CHAT_PFX);
		return;
	}
	new String:s_map[32];
	m_args.GetString(2, s_map, sizeof(s_map));
	if(!CVAR_matchplugin_use_maplist.BoolValue){
		fn_nextmap(s_map);
		return;
	}
	new map_cnt = GetArraySize(g_maplist);
	decl String:c_map[32];
	for (new i = 0; i < map_cnt; i++){
		GetArrayString(g_maplist, i, c_map, sizeof(c_map));
		if(StrEqual(c_map, s_map, false)){
			PrintToChatAll("[%s] Nextmap changed to %s", CHAT_PFX,	s_map);
			fn_nextmap(s_map);
			return;
		}
	}
	PrintToChat(client, "[%s] Map '%s' not found", CHAT_PFX,  s_map);
}
fn_nextmap(String:map[]){
	InsertServerCommand("sm_nextmap \"%s\"", map);
	InsertServerCommand("nextlevel \"%s\"", map);
	ServerExecute();
}

public cmd_fn_restartround(client, ArrayList:m_args){
	if(!(g_match_status == LIVE || g_match_status == MODULE_HANDLED)){
		PrintToChat(client, "[%s] Match is not running", CHAT_PFX);
		return;
	}
	MPINS_Native_VoteStart(client, "vote_restart_round", "Restart round?", "round restart");
}
public fn_restartround(){
	if(!(g_match_status == LIVE || g_match_status == MODULE_HANDLED))
		return;
	PrintToChatAll("[%s] Restarting round...", CHAT_PFX);
	InsertServerCommand("mp_restartround 5");
	ServerExecute();
}

public cmd_fn_restartgame(client, ArrayList:m_args){
	if(!(g_match_status == LIVE || g_match_status == MODULE_HANDLED)){
		PrintToChat(client, "[%s] Game not started yet", CHAT_PFX);
		return;
	}
	MPINS_Native_VoteStart(client, "vote_restart_game", "Restart game?", "game restart");
}
public fn_restartgame(){
	if(!(g_match_status == LIVE || g_match_status == MODULE_HANDLED))
		return;
	PrintToChatAll("[%s] Restarting game...", CHAT_PFX);
	InsertServerCommand("mp_restartgame 5");
	ServerExecute();
}

public cmd_fn_switchteams(client, ArrayList:m_args){
	MPINS_Native_VoteStart(client, "vote_switch_teams", "Switch teams?", "switch teams");
}
public fn_switchteams(){  //FIXME: allow only one team switch while round not running
	if(g_match_status == LIVE)
		CPrintToChatAll("[%s] {green}Teams will be switched", CHAT_PFX);
	else
		CPrintToChatAll("[%s] {green}Teams will be switched on round start", CHAT_PFX);
	InsertServerCommand("mp_switchteams");
	InsertServerCommand("mp_restartround 1");
	ServerExecute();
}

public cmd_fn_ready(client, ArrayList:m_args){
	new TEAM:team = TEAM:GetClientTeam(client);
	if(!(team == TEAM:SECURITY || team == TEAM:INSURGENTS))
		return;
	if(!MPINS_Native_GetTeamReadiness(team))
		MPINS_Native_SetTeamReadiness(team, true);
}

public cmd_fn_notready(client, ArrayList:m_args){
	new TEAM:team = TEAM:GetClientTeam(client);
	if(!(team == TEAM:SECURITY || team == TEAM:INSURGENTS))
		return;
	if(MPINS_Native_GetTeamReadiness(team))
		MPINS_Native_SetTeamReadiness(team, false);
}



public cmd_fn_kickspectators(client, ArrayList:m_args){
	new maxplayers = GetMaxClients();
	for (new x = 1; x <= maxplayers ; x++){
		if(!IsClientInGame(x))
			continue;
		if(TEAM:GetClientTeam(x) != TEAM:SPECTATORS)
			continue;
		KickClient(x, "Spectators was kicked");
	}
}


public cmd_fn_showpassword(client, ArrayList:m_args){
	new String:password[100];
	CVAR_sv_password.GetString(password, sizeof(password));
	CPrintToChat(client, "[%s] Password: {green}%s", CHAT_PFX, password);
}


public cmd_fn_execcfg(client, ArrayList:m_args){
	if(!(g_match_status == WAITING || g_match_status == ENDED)){
		PrintToChat(client, "[%s] Config can't be changed while match is running", CHAT_PFX);
		return;
	}
	if(m_args.Length < 3){
		cmd_fn_listcfg(client, m_args);
		return;
	}
	new String:s_cfg[32];
	m_args.GetString(2, s_cfg, sizeof(s_cfg));
	if(exec_config(s_cfg)){
		CPrintToChatAll("[%s] Loaded \"{green}%s{default}\" config", CHAT_PFX, s_cfg);
		if(!StrEqual(s_cfg, g_curcfg, false)){ //Advance map if loaded config differs
			strcopy(g_curcfg, sizeof(g_curcfg), s_cfg);
			map_advance();
		}
	}else{
		CPrintToChat(client, "[%s] Config not found: \"{green}%s{default}\"", CHAT_PFX, s_cfg);
		cmd_fn_listcfg(client, m_args);
	}
}


public cmd_fn_listcfg(client, ArrayList:m_args){
	new StringMapSnapshot:keys = g_configs.Snapshot();
	new String:buf_key[127];
	new String:buf_concat[512];

	for(new i = 0; i < keys.Length; i++){
		keys.GetKey(i, buf_key, sizeof(buf_key));
		if(StrEqual(buf_key, "default")) continue;
		if(i == 0)StrCat(buf_concat, sizeof(buf_concat), " {green}");
		else	StrCat(buf_concat, sizeof(buf_concat), ", {green}");
		StrCat(buf_concat, sizeof(buf_concat), buf_key);
		StrCat(buf_concat, sizeof(buf_concat), "{default}");
	}
	CPrintToChat(client, "[%s] Current config: {green}%s", CHAT_PFX, g_curcfg);
	CPrintToChat(client, "[%s] Available configs:%s", CHAT_PFX, buf_concat);
}


public cmd_fn_status(client, ArrayList:m_args){
	print_status(client);
}
public print_status(client){
	new String:match_status[32];
	if(	g_match_status == WAITING)				match_status = "waiting the teams to get ready";
	else if(g_match_status == STARTING)			match_status = "starting match";
	else if(g_match_status == LIVE_ON_RESTART)	match_status = "LOR";
	else if(g_match_status == LIVE)				match_status = "LIVE!";
	else if(g_match_status == STOPING)			match_status = "stoping";
	else if(g_match_status == ENDED)			match_status = "eneded";
	CPrintToChat(client, "[%s] Server config: {green}%s", CHAT_PFX, g_curcfg);
	CPrintToChat(client, "[%s] Game state: {green}%s", CHAT_PFX,  match_status);
	if(g_is_waiting_rdy){
		CPrintToChat(client, "Waiting readiness signal for %s", g_rdy_descr);
	}
	if(g_teams_rdy[SECURITY])	CPrintToChat(client, "Security: {green}READY");
	else				CPrintToChat(client, "Security: {red}NOT {default}READY");
	if(g_teams_rdy[INSURGENTS])	CPrintToChat(client, "Insurgency: {green}READY");
	else				CPrintToChat(client, "Insurgency: {red}NOT {default}READY");
}


public cmd_fn_help(client, ArrayList:m_args){
	CPrintToChat(client, "[%s] Help info printed into {green}console", CHAT_PFX);
	PrintToConsole(client, "Usage: %s COMMAND [arguments]", g_chat_command_prefix);
	PrintToConsole(client, "Arguments:");

	Call_StartForward(FWD_OnHelpCalled);
	Call_PushCell(client);
	Call_Finish();
}

public MPINS_OnHelpCalled(client){
    PrintToConsole(client, " r               Marks team as ready. After all teams are ready, executes config, generates server password and starts match");
    PrintToConsole(client, " nr              Marks team as unready");
    PrintToConsole(client, " stop            Stop match");
    PrintToConsole(client, " e CFGNAME       Exec config");
    PrintToConsole(client, " lc              List available configs");
    PrintToConsole(client, " cm MAPNAME      Changing map to MAPNAME");
    PrintToConsole(client, " nm MAPNAME      Changing nextmap to MAPNAME");
    PrintToConsole(client, " rg              Restart game");
    PrintToConsole(client, " rr              Round restart");
    PrintToConsole(client, " st              Switch teams");
    PrintToConsole(client, " ks              Kick spectators");
    PrintToConsole(client, " pw              Show password");
}


public player_welcome(client){
	if(!GetConVarBool(CVAR_matchplugin_welcome))
		return;
	CPrintToChat(client, "[%s] Type {green}%s help {default} for command reference", CHAT_PFX, g_chat_command_prefix);
	print_status(client);
}




public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max){
	CreateNative("MPINS_Native_SetMatchStatus", Native_SetMatchStatus);
	CreateNative("MPINS_Native_GetMatchStatus", Native_GetMatchStatus);
	CreateNative("MPINS_Native_ChatCmd",		Native_ChatCmd);
	CreateNative("MPINS_Native_RegCmd",			Native_RegCmd);
	CreateNative("MPINS_Native_RegVote",		Native_RegVote);
	CreateNative("MPINS_Native_VoteStart",		Native_VoteStart);
	CreateNative("MPINS_Native_VoteGetParams",  Native_VoteGetParams);

	CreateNative("MPINS_Native_SetWaitForReadiness", Native_SetWaitForReadiness);
	CreateNative("MPINS_Native_UnsetWaitForReadiness", Native_UnsetWaitForReadiness);
	CreateNative("MPINS_Native_GetCurrentReadinessFor", Native_GetCurrentReadinessFor);

	CreateNative("MPINS_Native_GetTeamReadiness", Native_GetTeamReadiness);
	CreateNative("MPINS_Native_SetTeamReadiness", Native_SetTeamReadiness);

	CreateNative("MPINS_Native_SetHostnamePostfix", Native_SetHostnamePostfix);

	FWD_OnMatchStatusChange = CreateGlobalForward("MPINS_OnMatchStatusChange", ET_Hook, Param_Cell, Param_CellByRef);
	FWD_OnChatCmd = CreateGlobalForward("MPINS_OnChatCmd", ET_Event, Param_Cell, Param_String);
	FWD_OnHelpCalled = CreateGlobalForward("MPINS_OnHelpCalled", ET_Hook, Param_Cell);

	FWD_OnTeamReady = CreateGlobalForward("MPINS_OnTeamReady", ET_Event, Param_Cell, Param_String, Param_String);
	FWD_OnTeamUnready = CreateGlobalForward("MPINS_OnTeamUnready", ET_Event, Param_Cell, Param_String, Param_String);
	FWD_OnAllTeamsReady = CreateGlobalForward("MPINS_OnAllTeamsReady", ET_Event, Param_String, Param_String);


	RegPluginLibrary("MPINS");
	return APLRes_Success;
}


/*
 * Natives
 */
public Native_RegCmd(Handle:plugin, int numParams){
	new String:cmd_alias[32];
	new String:cmd_fn_name[32];
	new Handle:cmd_plugin;
	GetNativeString(1, cmd_alias, sizeof(cmd_alias));
	GetNativeString(2, cmd_fn_name, sizeof(cmd_fn_name));
	cmd_plugin = GetNativeCell(3);

	g_cmds.SetString(cmd_alias, cmd_fn_name, false);
	g_cmds_fn.SetValue(cmd_fn_name, cmd_plugin, false);
}

public Native_RegVote(Handle:plugin, int numParams){
	new String:vote_name[32];
	new String:vote_fn_name[32];
	new Handle:vote_plugin;
	GetNativeString(1, vote_name, sizeof(vote_name));
	GetNativeString(2, vote_fn_name, sizeof(vote_fn_name));
	vote_plugin = GetNativeCell(3);

	g_votes.SetString(vote_name, vote_fn_name, false);
	g_votes_fn.SetValue(vote_fn_name, vote_plugin, false);
}


public Native_SetMatchStatus(Handle:plugin, int numParams){
	new MPINS_MatchStatus:new_status;
	new_status = GetNativeCell(1);

	g_new_match_status = new_status;
	if(new_status == g_match_status)
		return false;
	new MPINS_MatchStatus:status;
	MPINS_Native_GetMatchStatus(status);
	if(new_status != status)
		return false;
	g_match_status = status;
	if(status == WAITING)			on_match_waiting();
	else if(status == STARTING)		on_match_starting();
	else if(status == LIVE_ON_RESTART) on_match_live_on_restart();
	else if(status == LIVE)			on_match_live();
	else if(status == STOPING)		on_match_stoping();
	else if(status == ENDED)		on_match_ended();
	return true;
}



public Native_ChatCmd(Handle:plugin, int numParams){
	new client = GetNativeCell(1);
	new String:message[512];
	GetNativeString(2, message, sizeof(message));

	new Action:act = Plugin_Continue;
	Call_StartForward(FWD_OnChatCmd);
	Call_PushCell(client);
	Call_PushString(message);
	Call_Finish(act);
	SetNativeCellRef(3, act);
}


public Native_GetMatchStatus(Handle:plugin, int numParams){
	new MPINS_MatchStatus:old_status = g_match_status;
	new MPINS_MatchStatus:new_status = g_new_match_status;

	new Action:act = Plugin_Continue;
	Call_StartForward(FWD_OnMatchStatusChange);
	Call_PushCell(old_status);
	Call_PushCellRef(new_status);
	Call_Finish(act);
	if(act == Plugin_Changed || act == Plugin_Stop){
		g_match_status = new_status;
	}
	SetNativeCellRef(1, g_match_status);
}





/* Voting */
public int Handle_VoteMenu(Menu menu, MenuAction action, int param1, int param2){
	if(action == MenuAction_End){
		delete menu;
		g_voting_name[0] = 0;
		g_voting_tittle[0] = 0;
		g_voting_descr[0] = 0;
		g_voting_menu = null;
	}
}

public Native_VoteGetParams(Handle:plugin, int numParams){
	new name_size =   GetNativeCell(2);
	new tittle_size = GetNativeCell(4);

	SetNativeString(1, g_voting_name,   name_size+1,   false);
	SetNativeString(3, g_voting_tittle, tittle_size+1, false);
}


public Native_VoteStart(Handle:plugin, int numParams){
	if(IsVoteInProgress()){
		return false;
	}
	new client = GetNativeCell(1);
	new cooldown = CVAR_matchplugin_vote_cooldown.IntValue;
	new Float:et = GetEngineTime();
	if(g_voting_cNextvote[client] > et){
		PrintToChat(client, "[%s] You can vote again in %.f seconds", CHAT_PFX, (g_voting_cNextvote[client]-et));
		return false;
	}

	GetNativeString(2, g_voting_name, sizeof(g_voting_name));
	GetNativeString(3, g_voting_tittle, sizeof(g_voting_tittle));
	GetNativeString(4, g_voting_descr, sizeof(g_voting_descr));

	new String:buf_fn_name[64];
	if(g_votes.GetString(g_voting_name, buf_fn_name, sizeof(buf_fn_name))){
		new Handle:buf_fn_plugin;
		if(g_votes_fn.GetValue(buf_fn_name, buf_fn_plugin)){
			new VoteHandler:vote_fn;
			vote_fn = VoteHandler:GetFunctionByName(INVALID_HANDLE, buf_fn_name);
			if(vote_fn == INVALID_FUNCTION){
				vote_fn = VoteHandler:GetFunctionByName(INVALID_HANDLE, "VoteHandler_Generic");
				strcopy(g_voting_fn_name, sizeof(g_voting_fn_name), buf_fn_name);
				g_voting_fn_plugin = buf_fn_plugin;
			}

			PrintToChatAll("[%s] %N requested to %s", CHAT_PFX, client, g_voting_descr);
			g_voting_menu = new Menu(Handle_VoteMenu);
			g_voting_menu.VoteResultCallback = vote_fn;
			g_voting_menu.SetTitle(g_voting_tittle);
			g_voting_menu.AddItem(VOTE_OPT_YES, "Yes");
			g_voting_menu.AddItem(VOTE_OPT_NO, "No");
			g_voting_menu.ExitButton = false;
			g_voting_menu.DisplayVoteToAll(25);
			g_voting_cNextvote[client] = et+cooldown;
			return true;
		}
	}
	return false;
}


/* Vote Handlers */
public void VoteHandler_match_stop(Menu menu,
								   int num_votes,
								   int num_clients,
								   const int[][] client_info,
								   int num_items,
								   const int[][] item_info){
	new String:winner[64];
	new winner_votes;
	new g_vote_ratio = 100;

	menu.GetItem(item_info[0][VOTEINFO_ITEM_INDEX], winner, sizeof(winner));
	winner_votes = item_info[0][VOTEINFO_ITEM_VOTES];
	new winner_ratio = ((winner_votes * 100)/num_votes);
	PrintToChatAll("[%s] Vote: %d%% of players voted for %s", CHAT_PFX, winner_ratio, winner);
	if(winner_ratio >= g_vote_ratio){
		if(StrEqual(winner, VOTE_OPT_YES)){
			if(!(g_match_status == LIVE || g_match_status == MODULE_HANDLED)){
				PrintToChatAll("[%s] Game not running.", CHAT_PFX);
				return;
			}
			MPINS_Native_SetMatchStatus(STOPING);
		}
	}else{
		PrintToChatAll("[%s] Vote failed", CHAT_PFX);
	}
}
public void VoteHandler_restart_game(Menu menu,
									 int num_votes,
									 int num_clients,
									 const int[][] client_info,
									 int num_items,
									 const int[][] item_info){
	new String:winner[64];
	new winner_votes;
	new g_vote_ratio = 100;

	menu.GetItem(item_info[0][VOTEINFO_ITEM_INDEX], winner, sizeof(winner));
	winner_votes = item_info[0][VOTEINFO_ITEM_VOTES];
	new winner_ratio = ((winner_votes * 100)/num_votes);
	PrintToChatAll("[%s] Vote: %d%% of players voted for %s", CHAT_PFX, winner_ratio, winner);
	if(winner_ratio >= g_vote_ratio){
		if(StrEqual(winner, VOTE_OPT_YES)){
			fn_restartgame();
		}
	}else{
		PrintToChatAll("[%s] Vote failed", CHAT_PFX);
	}
}
public void VoteHandler_restart_round(Menu menu,
									  int num_votes,
									  int num_clients,
									  const int[][] client_info,
									  int num_items,
									  const int[][] item_info){
	new String:winner[64];
	new winner_votes;
	new g_vote_ratio = 100;

	menu.GetItem(item_info[0][VOTEINFO_ITEM_INDEX], winner, sizeof(winner));
	winner_votes = item_info[0][VOTEINFO_ITEM_VOTES];
	new winner_ratio = ((winner_votes * 100)/num_votes);
	PrintToChatAll("[%s] Vote: %d%% of players voted for %s", CHAT_PFX, winner_ratio, winner);
	if(winner_ratio >= g_vote_ratio){
		if(StrEqual(winner, VOTE_OPT_YES)){
			fn_restartround();
		}
	}else{
		PrintToChatAll("[%s] Vote failed", CHAT_PFX);
	}
}
public void VoteHandler_switch_teams(Menu menu,
									 int num_votes,
									 int num_clients,
									 const int[][] client_info,
									 int num_items,
									 const int[][] item_info){
	new String:winner[64];
	new winner_votes;
	new g_vote_ratio = 100;

	menu.GetItem(item_info[0][VOTEINFO_ITEM_INDEX], winner, sizeof(winner));
	winner_votes = item_info[0][VOTEINFO_ITEM_VOTES];
	new winner_ratio = ((winner_votes * 100)/num_votes);
	PrintToChatAll("[%s] Vote: %d%% of players voted for %s", CHAT_PFX, winner_ratio, winner);
	if(winner_ratio >= g_vote_ratio){
		if(StrEqual(winner, VOTE_OPT_YES)){
			fn_switchteams();
		}
	}else{
		PrintToChatAll("[%s] Vote failed", CHAT_PFX);
	}
}

/*
 * Hack to pass VoteHandler to dynamic function in external plugin
 */
public void VoteHandler_Generic(Menu menu,
								int num_votes,
								int num_clients,
								const int[][] client_info,
								int num_items,
								const int[][] item_info){
	new client_info_index[50];
	new client_info_item[50];
	new item_info_index[32];
	new item_info_votes[32];
	for(new i=0;i<num_clients;i++){
		client_info_index[i] = client_info[i][VOTEINFO_CLIENT_INDEX];
		client_info_item[i] = client_info[i][VOTEINFO_CLIENT_ITEM];
	}
	for(new i=0;i<num_items;i++){
		item_info_index[i] = item_info[i][VOTEINFO_ITEM_INDEX];
		item_info_votes[i] = item_info[i][VOTEINFO_ITEM_VOTES];
	}

	new Function:vote_fn = GetFunctionByName(g_voting_fn_plugin, g_voting_fn_name);
	Call_StartFunction(g_voting_fn_plugin, vote_fn);
	Call_PushCell(menu);
	Call_PushCell(num_votes);
	Call_PushCell(num_clients);
	Call_PushArray(client_info_index, sizeof(client_info_index));
	Call_PushArray(client_info_item, sizeof(client_info_item));
	Call_PushCell(num_items);
	Call_PushArray(item_info_index, sizeof(item_info_index));
	Call_PushArray(item_info_votes, sizeof(item_info_votes));
	Call_Finish();
}
/* ============ */





public Native_SetWaitForReadiness(Handle:plugin, int numParams){
	new String:new_rdy_for[64];
	new String:new_rdy_descr[256];
	GetNativeString(1, new_rdy_for, sizeof(new_rdy_for));
	GetNativeString(2, new_rdy_descr, sizeof(new_rdy_descr));

	if(g_is_waiting_rdy){
		PrintToServer("[%s] Already waiting for team readines", CHAT_PFX);
		return;
	}
	g_is_waiting_rdy = true;
	g_rdy_for = new_rdy_for;
	g_rdy_descr = new_rdy_descr;
	CPrintToChatAll("[%s] Type {green}%s ready {default}when all of your team are ready for %s", CHAT_PFX,  g_chat_command_prefix, g_rdy_descr);
}
public Native_UnsetWaitForReadiness(Handle:plugin, int numParams){
	new String:rdy_for[64];
	GetNativeString(1, rdy_for, sizeof(rdy_for));

	if(!StrEqual(g_rdy_for, rdy_for)){
		return;
	}
	g_is_waiting_rdy = false;
	for(new TEAM:i; i<TEAM;i++){
		g_teams_rdy[i] = false;
	}
}

public Native_GetCurrentReadinessFor(Handle:plugin, int numParams){
	new str_size = GetNativeCell(2);
	SetNativeString(1, g_rdy_for, str_size+1, false);
}

public Native_GetTeamReadiness(Handle:plugin, int numParams){
	new TEAM:team = TEAM:GetNativeCell(1);
	if(!g_is_waiting_rdy)
		return false;
	if(g_teams_rdy[team])
		return true;
	return false;
}
public Native_SetTeamReadiness(Handle:plugin, int numParams){
	new TEAM:team = TEAM:GetNativeCell(1);
	new bool:new_rdy = GetNativeCell(2);
	if(!g_is_waiting_rdy)
		return;
	if(new_rdy == g_teams_rdy[team])
		return;
	if(new_rdy){
		Call_StartForward(FWD_OnTeamReady);
		Call_PushCell(team);
		Call_PushString(g_rdy_for);
		Call_PushString(g_rdy_descr);
		Call_Finish();
	}else{
		Call_StartForward(FWD_OnTeamUnready);
		Call_PushCell(team);
		Call_PushString(g_rdy_for);
		Call_PushString(g_rdy_descr);
		Call_Finish();
	}
}

public Native_SetHostnamePostfix(Handle:plugin, int numParams){
	if(!CVAR_matchplugin_hostname_status)
		return;
	decl String:postfix[64];
	decl String:buf_h[128];
	GetNativeString(1, postfix, sizeof(postfix));
	strcopy(buf_h, sizeof(buf_h), g_hostname);
	StrCat(buf_h, sizeof(buf_h), postfix);
	CVAR_hostname.SetString(buf_h, true);
}

SetIdlingHostname(){
	if(!CVAR_matchplugin_hostname_showpw.BoolValue)
		return;
	decl String:password[100];
	CVAR_sv_password.GetString(password, sizeof(password));
	if(StrEqual(password, ""))
		return;
	decl String:buf_h[128];
	Format(buf_h, sizeof(buf_h), "pw: %s", password);
	UpdateHostnamePostfix(buf_h);
}



public Action:MPINS_OnTeamReady(TEAM:team, const String:rdy_for[], const String:rdy_descr[]){
	new String:TeamName[32];
	InsGetTeamName(team, TeamName, sizeof(TeamName));

	CPrintToChatAll("[%s] {green}%s {default}team ready for %s", CHAT_PFX, TeamName, rdy_descr);
	g_teams_rdy[team] = true;
	if(g_teams_rdy[team:SECURITY] && g_teams_rdy[team:INSURGENTS]){
		Call_StartForward(FWD_OnAllTeamsReady);
		Call_PushString(g_rdy_for);
		Call_PushString(g_rdy_descr);
		Call_Finish();
	}
	return Plugin_Continue;
}

public Action:MPINS_OnTeamUnready(TEAM:team, const String:rdy_for[], const String:rdy_descr[]){
	new String:TeamName[32];
	InsGetTeamName(team, TeamName, sizeof(TeamName));

	CPrintToChatAll("[%s] {green}%s team NOT ready for %s", CHAT_PFX, TeamName, rdy_descr);
	g_teams_rdy[team] = false;
	return Plugin_Continue;
}

public Action:MPINS_OnAllTeamsReady(const String:rdy_for[], const String:rdy_descr[]){
	PrintToChatAll("[%s] Both teams ready for %s", CHAT_PFX, rdy_descr);
	MPINS_Native_UnsetWaitForReadiness(rdy_for);
	if(StrEqual(rdy_for, sig_WaitingForMatchStart)){
		MPINS_Native_SetMatchStatus(STARTING);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public UpdateHostnamePostfix(String:status[]){
	decl String:buf[64];
	if(CVAR_matchplugin_hostname_showcfg.BoolValue){
		Format(buf, sizeof(buf), "%s | %s", g_curcfg, status);
	}else{
		Format(buf, sizeof(buf), "%s",  status);
	}
	MPINS_Native_SetHostnamePostfix(buf);
}

public Action:Timer_check_players(Handle:timer){
	for(new TEAM:team; team<TEAM;team++){
		if(team == TEAM:NONE || team == TEAM:SPECTATORS)
			continue;
		if(g_team_player_cnt[team]<1){
			new String:rdy_for[64];
			MPINS_Native_GetCurrentReadinessFor(rdy_for, sizeof(rdy_for));
			if(StrEqual(rdy_for, sig_WaitingForMatchStart)){
				MPINS_Native_SetTeamReadiness(team, false);
			}
			MPINS_Native_SetMatchStatus(WAITING);
		}
	}

	if(g_player_cnt < 2){  // Stop the match if only one player left
		if(!(g_match_status == MPINS_MatchStatus:WAITING ||
			 g_match_status == MPINS_MatchStatus:STOPING ||
			 g_match_status == MPINS_MatchStatus:ENDED
			 )){
			MPINS_Native_SetMatchStatus(STOPING);
		}
	}
}


Set_sv_hibernate_when_empty(val){
	ServerCommand("sv_hibernate_when_empty %d", val);
	ServerExecute();
}

public Action:Timer_sv_hibernate_when_empty(Handle:timer, val){
	Set_sv_hibernate_when_empty(val);
}






DumpClientsToChat(){
	new TEAM:team;
	decl String:AuthID[32];
	decl String:team_n[32];
	for(new TEAM:t; t < TEAM; t++){
		if(t == TEAM:NONE || t == TEAM:SPECTATORS)
			continue;
		InsGetTeamName(t, team_n, sizeof(team_n));
		CPrintToChatAll("{green}   %s", team_n);
		for(new i = 1; i <= MaxClients; i++){
			if(!IsClientInGame(i) || IsFakeClient(i))
				continue;
			team = TEAM:GetClientTeam(i);
			if(team != t)
				continue;
			GetClientAuthId(i, AuthId_Engine, AuthID, sizeof(AuthID));
			ReplaceString(AuthID, sizeof(AuthID), "STEAM_", "");
			CPrintToChatAll("{green}       %N {default}<%s>", i, AuthID);
		}
	}
}



public Action:start_stage_1(Handle:timer){
	CPrintToChatAll("{green}%s","===============================");
	CPrintToChatAll("{green}%s","Game Ready!");
	CPrintToChatAll("{green}%s","===============================");
	DumpClientsToChat();
	CPrintToChatAll("{green}%s","===============================");
	CreateTimer(7.0, start_stage_2);
}

public Action:start_stage_2(Handle:timer){
	if(g_match_status != STARTING) return;
	//CPrintToChatAll("{green}%s","-----> 5 <-----");
	CreateTimer(1.0, start_stage_3);
}

public Action:start_stage_3(Handle:timer){
	if(g_match_status != STARTING) return;
	//CPrintToChatAll("{green}%s","----> 4 <----");
	CreateTimer(1.0, start_stage_4);
}

public Action:start_stage_4(Handle:timer){
	if(g_match_status != STARTING) return;
	//CPrintToChatAll("{green}%s","---> 3 <---");
	CreateTimer(1.0, start_stage_5);
}

public Action:start_stage_5(Handle:timer){
	if(g_match_status != STARTING) return;
	//CPrintToChatAll("{green}%s","--> 2 <--");
	CreateTimer(1.0, start_stage_6);
}

public Action:start_stage_6(Handle:timer){
	if(g_match_status != STARTING) return;
	//CPrintToChatAll("{green}%s","-> 1 <-");
	CreateTimer(1.0, start_stage_7);
}

public Action:start_stage_7(Handle:timer){
	if(g_match_status != STARTING) return;
	new String:password[100];
	CVAR_sv_password.GetString(password, sizeof(password));

	CPrintToChatAll("{green}%s","=>--!LIVE ON RESTART!--<=");
	if(CVAR_matchplugin_generate_pw.BoolValue)
		CPrintToChatAll("[%s] Password was set to: {green}%s", CHAT_PFX, password);
	InsertServerCommand("mp_restartgame 1");
	ServerExecute();
	MPINS_Native_SetMatchStatus(LIVE_ON_RESTART);
}
