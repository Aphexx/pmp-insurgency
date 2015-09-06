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
	version = "2.0.0a",
	url = "http://www.sourcemod.net/"
};


enum PAUSE_STATE{
	NOT_PAUSED,
	PAUSED,
	UNPAUSING
};
new PAUSE_STATE:g_paused = NOT_PAUSED;
new MPINS_MatchStatus:g_match_status = WAITING;
new MPINS_MatchStatus:g_new_match_status;
new Handle:FWD_OnMatchStatusChange;
new Handle:FWD_OnChatCmd;

new const String:chat_pfx[] = "MP";
#define TEAM_SPECTATORS 1
#define TEAM_SECURITY 2
#define TEAM_INSURGENTS 3
new bool:g_team_r[4];
new g_team_player_cnt[4];
new g_player_cnt;

new String:g_chat_command_prefix[32] = "#.#";
new Handle:g_maplist;


new StringMap:g_cmds;		//"cmd_alias" -> "fn_name"
new StringMap:g_cmds_fn;	//"fn_name" -> "plugin_handler"
new StringMap:g_cmds_help;  //"cmd" -> "help info"'
//new cmds[32][MPINS_CMD];


new StringMap:g_configs;
new String:g_curcfg[64] = "default";
new bool:g_SMC_configs_sec = false;

new bool:g_round_end = false;

new String:g_hostname[64];

new Handle:g_CVAR_pmp_cmd_prefix;
new Handle:g_CVAR_pmp_welcome;
new Handle:g_CVAR_pmp_hostname_tail_status;
new Handle:g_CVAR_pmp_hostname;
new Handle:g_CVAR_pmp_disable_kill;






public OnPluginStart(){
	InitVars();
	InitCVARs();
	InitCMDs();
	InitHooks();

	/*
	new zz[MPINS_CMD];
	g_zarr.GetArray(0, zz[0]);
	PrintToServer(">>>>>>>>>>>>>>>>>>>>>>>>>>>>> ZZ: %s", zz[MPINS_CMD:cmd_name]);
	g_zarr.GetArray(1, zz[0]);
	PrintToServer(">>>>>>>>>>>>>>>>>>>>>>>>>>>>> ZZ2: %s", zz[MPINS_CMD:cmd_name]);
	*/


	AutoExecConfig(true);
	load_config_file("configs/match_plugin.txt");
	exec_config(g_curcfg);
}
public OnPluginEnd(){
	RemoveCVARs();
	RemoveCMDs();
	RemoveHooks();
}
public OnConfigsExecuted(){
	////new Handle:cv_hostname = FindConVar("hostname");
	////GetConVarString(cv_hostname, g_hostname, sizeof(g_hostname));

	//GetConVarString(g_CVAR_pmp_hostname, g_hostname, sizeof(g_hostname));

	new maplist_serial = -1;
	ReadMapList(g_maplist, maplist_serial, "default", MAPLIST_FLAG_CLEARARRAY);

	//change_status(MATCH_STATUS:WAITING);
}



public InitVars(){
	g_maplist = CreateArray(32);
	g_configs = new StringMap();

	g_cmds = new StringMap();
	g_cmds_fn = new StringMap();
	g_cmds_help = new StringMap();



	g_cmds.SetString("help",				"cmd_fn_help");
	g_cmds.SetString("h",				"cmd_fn_help");
	g_cmds.SetString("start",			"cmd_fn_start");
	g_cmds.SetString("e",				"cmd_fn_execcfg");
	g_cmds.SetString("exec",			 	"cmd_fn_execcfg");
	g_cmds.SetString("execcfg",		 	"cmd_fn_execcfg");
	g_cmds.SetString("r",				"cmd_fn_ready");
	g_cmds.SetString("ready",			"cmd_fn_ready");
	g_cmds.SetString("nr",			 	"cmd_fn_notready");
	g_cmds.SetString("notready",		"cmd_fn_notready");
	g_cmds.SetString("stop",			"cmd_fn_stop");
	g_cmds.SetString("cm",				"cmd_fn_changemap");
	g_cmds.SetString("map",				"cmd_fn_changemap");
	g_cmds.SetString("nm",				"cmd_fn_nextmap");
	g_cmds.SetString("nextmap",			"cmd_fn_nextmap");
	g_cmds.SetString("p",				"cmd_fn_pause");
	g_cmds.SetString("pause",			"cmd_fn_pause");
	g_cmds.SetString("rr",				"cmd_fn_restartround");
	g_cmds.SetString("restartround",	"cmd_fn_restartround");
	g_cmds.SetString("rg",				"cmd_fn_restartgame");
	g_cmds.SetString("restartgame",		"cmd_fn_restartgame");
	g_cmds.SetString("st",				"cmd_fn_switchteams");
	g_cmds.SetString("switchteams",		"cmd_fn_switchteams");
	g_cmds.SetString("sp",				"cmd_fn_showpassword");
	g_cmds.SetString("showpassword",		"cmd_fn_showpassword");
	g_cmds.SetString("status",			"cmd_fn_status");
	g_cmds.SetString("lc",				"cmd_fn_listcfg");
	g_cmds.SetString("listcfg",			"cmd_fn_listcfg");
	g_cmds.SetString("listconfig",		"cmd_fn_listcfg");
	g_cmds.SetString("ks",				"cmd_fn_kickspectators");
	g_cmds.SetString("kickspectators",	"cmd_fn_kickspectators");


	new Handle:ch = GetMyHandle();
	g_cmds_fn.SetValue("cmd_fn_help", ch);
	g_cmds_fn.SetValue("cmd_fn_start", ch);
	g_cmds_fn.SetValue("cmd_fn_execcfg", ch);
	g_cmds_fn.SetValue("cmd_fn_ready", ch);
	g_cmds_fn.SetValue("cmd_fn_notready", ch);
	g_cmds_fn.SetValue("cmd_fn_stop", ch);
	g_cmds_fn.SetValue("cmd_fn_changemap", ch);
	g_cmds_fn.SetValue("cmd_fn_nextmap", ch);
	g_cmds_fn.SetValue("cmd_fn_pause", ch);
	g_cmds_fn.SetValue("cmd_fn_restartround", ch);
	g_cmds_fn.SetValue("cmd_fn_restartgame", ch);
	g_cmds_fn.SetValue("cmd_fn_switchteams", ch);
	g_cmds_fn.SetValue("cmd_fn_showpassword", ch);
	g_cmds_fn.SetValue("cmd_fn_status", ch);
	g_cmds_fn.SetValue("cmd_fn_listcfg", ch);
	g_cmds_fn.SetValue("cmd_fn_kickspectators", ch);

	//	g_cmds_help.SetValue();

	//new String:arrd[2][64] = {"wolo", "lol"};
	//g_cmds_help.SetArray("lol", arrd);
	//arrd = {"hui", "pizda"};
	//g_cmds_help.SetValue();
	/*
	g_cmds_help.SetValue("ready", "r				   Marks team as ready/unready. After all teams are ready, executes config, generates server password and starts match");
	g_cmds_help.SetValue("stop",  "		   Stop match");
	g_cmds_help.SetValue(" e CFGNAME		   Exec config");
	g_cmds_help.SetValue(" lc				   List available configs");
	g_cmds_help.SetValue(" cm MAPNAME		   Changing map to MAPNAME");
	g_cmds_help.SetValue(" nm MAPNAME		   Changing nextmap to MAPNAME");
	g_cmds_help.SetValue(" p				   Pause/unpause game");
	g_cmds_help.SetValue(" rg				   Restart game");
	g_cmds_help.SetValue(" rr				   Round restart");
	g_cmds_help.SetValue(" st				   Switch teams");
	g_cmds_help.SetValue(" ks				   Kick spectators");
	g_cmds_help.SetValue(" sp				   Show password");
	*/

}

public InitCVARs(){
	g_CVAR_pmp_cmd_prefix =				CreateConVar("sm_pmp_cmd_prefix",			g_chat_command_prefix,	"Chat command prefix");
	g_CVAR_pmp_welcome =				CreateConVar("sm_pmp_welcome",				"1",					"Enable player welcome message");
	g_CVAR_pmp_hostname_tail_status =	CreateConVar("sm_pmp_hostname_tail_status",	"0",					"Enables displaying server status at hostname tail");
	g_CVAR_pmp_hostname =				CreateConVar("sm_pmp_hostname",				"Your hostname | ",		"Dynamic hostname");
	g_CVAR_pmp_disable_kill =			CreateConVar("sm_pmp_disable_kill",			"1",					"Disable 'kill' cmd for players");
	HookConVarChange(g_CVAR_pmp_cmd_prefix,		OnChange_CVAR_pmp_cmd_prefix);
	HookConVarChange(g_CVAR_pmp_disable_kill,	OnChange_CVAR_pmp_disable_kill);
}
public RemoveCVARs(){
	UnhookConVarChange(g_CVAR_pmp_cmd_prefix, OnChange_CVAR_pmp_cmd_prefix);
	UnhookConVarChange(g_CVAR_pmp_disable_kill,	OnChange_CVAR_pmp_disable_kill);
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
	HookEvent("player_team", GameEvents_player_team);
}
public RemoveHooks(){
	UnhookEvent("game_start", GameEvents_GameStart);
	UnhookEvent("game_end", GameEvents_GameEnd);
	UnhookEvent("round_start", GameEvents_RoundStart, EventHookMode_PostNoCopy);
	UnhookEvent("round_end", GameEvents_RoundEnd, EventHookMode_PostNoCopy);
	UnhookEvent("player_team", GameEvents_player_team);
}




/*
 * CVARS Hooks
 */
public OnChange_CVAR_pmp_cmd_prefix(Handle:convar, const String:oldValue[], const String:newValue[]){
	strcopy(g_chat_command_prefix, sizeof(g_chat_command_prefix), newValue);
	SetConVarString(convar, g_chat_command_prefix);
}
public OnChange_CVAR_pmp_disable_kill(Handle:convar, const String:oldValue[], const String:newValue[]){
	new disable_kill = GetConVarBool(convar);
	if(disable_kill)
		SetCommandFlags("kill", GetCommandFlags("kill") | FCVAR_CHEAT);
	else
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
	g_round_end = false;
	if(g_match_status == MPINS_MatchStatus:LIVE_ON_RESTART){
		MPINS_Native_SetMatchStatus(MPINS_MatchStatus:LIVE);
	}
}
public GameEvents_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast){
	g_round_end = true;
}
public Action:GameEvents_player_team(Handle:event, const String:name[], bool:dontBroadcast){
	//new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new oldteam = GetEventInt(event, "oldteam"); 
	new team = GetEventInt(event, "team");


	g_team_player_cnt[team]++;
	if(oldteam){
		g_team_player_cnt[oldteam]--;
		if(g_team_player_cnt[oldteam]<1){
			if(oldteam != TEAM_SPECTATORS)
				team_set_notready(oldteam);
		}
	}
	//FIXME
	/*
	  if(oldteam && team != oldteam){
	  if(g_match_status == LIVE){
	  if(g_paused == PAUSE_STATE:NOT_PAUSED){
	  PrintToChatAll("[%s] Auto pausing game due player team change", chat_pfx);
	  pause_game();
	  }
	  }
	  }
	*/
	return Plugin_Continue;
}







public Action:map_advance(){
	//if(g_player_cnt > 0)
	//	return;
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


public pause_game(){
	g_paused = PAUSE_STATE:PAUSED;
	InsertServerCommand("pause");
	ServerExecute();
}



public Action:Command_Say(client, args){
	if (client <= 0 || client > MaxClients)
		return Plugin_Continue;
	new String:message[512];
	GetCmdArgString(message, sizeof(message));
	StripQuotes(message);
	TrimString(message);

	//new String:m_args[6][512];
	//new ArrayList:m_args = new ArrayList();
	//new m_args_cnt;
	//m_args_cnt = ExplodeString(message, " ", m_args, sizeof(m_args), sizeof(m_args[]), true);	 //TODO:replace by BreakString

	//new Action:res = MPINS_Native_OnChatCmd(client, m_args_cnt, m_args);
	new Action:res = Action:MPINS_Native_ChatCmd(client, message);
	if(res == Plugin_Continue)
		return Plugin_Continue;
	else
		return Plugin_Handled;
	/*
	if(g_paused == PAUSE_STATE:PAUSED || g_paused == PAUSE_STATE:UNPAUSING){ //TODO: Add team chat support
		new String:cname[50];
		GetClientName(client, cname, sizeof(cname));
		if(ti == TEAM_SECURITY)
			CPrintToChatAll("[%s] {red}%s: {default}%s", chat_pfx, cname, message);
		else if(ti == TEAM_INSURGENTS)
			CPrintToChatAll("[%s] {blue}%s: {default}%s", chat_pfx,	 cname, message);
		return Plugin_Handled;
	}
	*/
	return Plugin_Continue;
}


public MPINS_OnChatCmd(client, const String:message[]){
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
	new ti = GetClientTeam(client);
	if(args_cnt < 1){
		cmd_fn_help(client, largs);
		return Plugin_Handled;
	}
	if(ti == TEAM_SPECTATORS){ // FIXME
		return Plugin_Continue;
	}

	PrintToServer("args_cnt: %d", args_cnt);

	new String:buf_fn_name[64];
	if(g_cmds.GetString(args[1], buf_fn_name, sizeof(buf_fn_name))){
		new Handler:buf_fn_plugin;
		if(g_cmds_fn.GetValue(buf_fn_name, buf_fn_plugin)){
			new Function:cmd_fn = GetFunctionByName(buf_fn_plugin, buf_fn_name);
			Call_StartFunction(buf_fn_plugin, cmd_fn);
			Call_PushCell(client);
			Call_PushCell(largs);
			Call_Finish();
		}else{
			PrintToChat(client, "[%s] ERROR", chat_pfx);
		}
	}else{
		PrintToChat(client, "[%s] Unknown command\nTry \"%s help\" for command list.", chat_pfx, g_chat_command_prefix);
	}
    delete largs;

	/*
	new StringMapSnapshot:keys_cmds = g_cmds.Snapshot();
	new String:buf_key[64];
	new String:buf_fn_name[64];
	for(new ci = 0; ci < keys_cmds.Length; ci++){
		keys.GetKey(ci, buf_key, sizeof(buf_key));
		if(StrEqual(buf_key, args[1])){
			StrCopy(buf_fn_name, 
					}
		if(i == 0)StrCat(buf_concat, sizeof(buf_concat), " {green}");
		else	StrCat(buf_concat, sizeof(buf_concat), ", {green}");
		StrCat(buf_concat, sizeof(buf_concat), buf_key);
		StrCat(buf_concat, sizeof(buf_concat), "{default}");
	}
	CPrintToChat(client, "[%s] Current config: {green}%s", chat_pfx, g_curcfg);
	CPrintToChat(client, "[%s] Available configs:%s", chat_pfx, buf_concat);
	*/
	/*
	// FIXME: clean this shit
	if(StrEqual(args[1], "help"))				cmd_fn_help(client, args);
	else if(StrEqual(args[1], "h"))				cmd_fn_help(client, args);
	else if(StrEqual(args[1], "start"))			cmd_fn_start(client, args);
	else if(StrEqual(args[1], "e"))				cmd_fn_execcfg(client, args);
	else if(StrEqual(args[1], "exec"))			cmd_fn_execcfg(client, args);
	else if(StrEqual(args[1], "execcfg"))		cmd_fn_execcfg(client, args);
	else if(StrEqual(args[1], "r"))				cmd_fn_ready(client, args);
	else if(StrEqual(args[1], "ready"))			cmd_fn_ready(client, args);
	else if(StrEqual(args[1], "nr"))			cmd_fn_notready(client, args);
	else if(StrEqual(args[1], "notready"))		cmd_fn_notready(client, args);
	else if(StrEqual(args[1], "stop"))			cmd_fn_stop(client, args);
	else if(StrEqual(args[1], "cm"))			cmd_fn_changemap(client, args);
	else if(StrEqual(args[1], "map"))			cmd_fn_changemap(client, args);
	else if(StrEqual(args[1], "nm"))			cmd_fn_nextmap(client, args);
	else if(StrEqual(args[1], "nextmap"))		cmd_fn_nextmap(client, args);
	else if(StrEqual(args[1], "p"))				cmd_fn_pause(client, args);
	else if(StrEqual(args[1], "pause"))			cmd_fn_pause(client, args);
	else if(StrEqual(args[1], "rr"))			cmd_fn_restartround(client, args);
	else if(StrEqual(args[1], "restartround"))	cmd_fn_restartround(client, args);
	else if(StrEqual(args[1], "rg"))			cmd_fn_restartgame(client, args);
	else if(StrEqual(args[1], "restartgame"))	cmd_fn_restartgame(client, args);
	else if(StrEqual(args[1], "st"))			cmd_fn_switchteams(client, args);
	else if(StrEqual(args[1], "switchteams"))	cmd_fn_switchteams(client, args);
	else if(StrEqual(args[1], "sp"))			cmd_fn_showpassword(client, args);
	else if(StrEqual(args[1], "showpassword"))	cmd_fn_showpassword(client, args);
	else if(StrEqual(args[1], "status"))		cmd_fn_status(client, args);
	else if(StrEqual(args[1], "lc"))			cmd_fn_listcfg(client, args);
	else if(StrEqual(args[1], "listcfg"))		cmd_fn_listcfg(client, args);
	else if(StrEqual(args[1], "listconfig"))	cmd_fn_listcfg(client, args);
	else if(StrEqual(args[1], "ks"))			cmd_fn_kickspectators(client, args);
	else if(StrEqual(args[1], "kickspectators"))cmd_fn_kickspectators(client, args);
	else{
		PrintToChat(client, "[%s] Unknown command\nTry \"%s help\" for command list.", chat_pfx, g_chat_command_prefix);
	}
	*/
	return Plugin_Handled;
}








public on_match_waiting(){
	exec_config(g_curcfg);

	g_team_r[TEAM_SECURITY] = false;
	g_team_r[TEAM_INSURGENTS] = false;
	g_paused = PAUSE_STATE:NOT_PAUSED;
	CPrintToChatAll("[%s] {green}Not ready", chat_pfx);
	InsertServerCommand("mp_minteamplayers 50");
	InsertServerCommand("mp_joinwaittime 100000");
	InsertServerCommand("unpause");
	ServerExecute();
}

public on_match_starting(){
	new String:passwd[5];
	new passwd_r = GetRandomInt(1000, 9999);
	IntToString(passwd_r, passwd, sizeof(passwd));

	InsertServerCommand("mp_minteamplayers 1");
	InsertServerCommand("mp_joinwaittime 1");
	InsertServerCommand("sv_password \"%s\"", passwd);
	ServerExecute();

	//change_concat_to_hostname("Match in progress");

	CreateTimer(1.0, start_stage_1);
}

public on_match_live_on_restart(){
	InsertServerCommand("mp_restartgame 1");
	ServerExecute();
}


public on_match_live(){
	CPrintToChatAll("{green}%s","=>|GL|--!LIVE!--|HF|<=");
	g_team_r[TEAM_SECURITY] = false;
	g_team_r[TEAM_INSURGENTS] = false;
}

public on_match_stoping(){
	CPrintToChatAll("[%s] {green}%s","Stoping match", chat_pfx);
	InsertServerCommand("mp_restartgame 1");
	ServerExecute();
	MPINS_Native_SetMatchStatus(WAITING);
}

public on_match_ended(){

}










/*
public void OnPluginStart(){
	RegServerCmd("sm_mp_test", Command_Test);
}
public Action Command_Test(int args){
	new MPINS_MatchStatus:MS;
	MS = MPINS_Native_GetMatchStatus();
	PrintToServer("MS: %d", MS);
	return Plugin_Handled;
}
*/











public Action:MPINS_OnMatchStatusChange(MPINS_MatchStatus:old_status, &MPINS_MatchStatus:new_status){
	PrintToChatAll("[MP] >>> %d -> %d", old_status, new_status);
	PrintToServer("[MP] >>> %d -> %d", old_status, new_status);
	if(g_new_match_status != NONE){
		PrintToServer("MP::Changing Status to: %d", g_new_match_status);
		new_status = g_new_match_status;
		g_new_match_status = NONE;
		return Plugin_Changed;
	}
	return Plugin_Continue;
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



public exec_config(String:cfgName[]){
	new String:cfgFile[127];

	if(g_configs.GetString(cfgName, cfgFile, sizeof(cfgFile))){
		InsertServerCommand("exec %s", cfgFile);
		ServerExecute();
		return true;
	}
	return false;
}







/*
 * FN
 */


public cmd_fn_start(client, ArrayList:m_args){
	if(g_match_status == WAITING){
		MPINS_Native_SetMatchStatus(STARTING);
		return;
	}
	PrintToChat(client, "[%s] Game already started!", chat_pfx);
}
public cmd_fn_stop(client, ArrayList:m_args){
	if(g_match_status == LIVE){
		MPINS_Native_SetMatchStatus(STOPING);
		return;
	}
	PrintToChat(client, "[%s] Game not running.", chat_pfx);
}



public cmd_fn_changemap(client, ArrayList:m_args){
	if(m_args.Length < 3){
		PrintToChat(client, "[%s] Specify map name", chat_pfx);
		return;
	}
	new String:s_map[32];
	m_args.GetString(2, s_map, sizeof(s_map));
	new map_cnt = GetArraySize(g_maplist);
	decl String:c_map[32];
	for (new i = 0; i < map_cnt; i++){
		GetArrayString(g_maplist, i, c_map, sizeof(c_map));
		if(StrEqual(c_map, s_map)){
			InsertServerCommand("sm_nextmap \"%s\"", s_map);
			InsertServerCommand("nextlevel \"%s\"", s_map);
			InsertServerCommand("sm_map \"%s\"", s_map); //FIXME: timeout
			ServerExecute();
			return;
		}
	}
	PrintToChat(client, "[%s] Map '%s' not found", chat_pfx, s_map);
}
public cmd_fn_nextmap(client, ArrayList:m_args){
	if(m_args.Length < 3){
		PrintToChat(client, "[%s] Specify map name", chat_pfx);
		return;
	}
	new String:s_map[32];
	m_args.GetString(2, s_map, sizeof(s_map));
	new map_cnt = GetArraySize(g_maplist);
	decl String:c_map[32];
	for (new i = 0; i < map_cnt; i++){
		GetArrayString(g_maplist, i, c_map, sizeof(c_map));
		if(StrEqual(c_map, s_map)){
			PrintToChatAll("[%s] Nextmap changed to %s", chat_pfx,	s_map);
			InsertServerCommand("sm_nextmap \"%s\"", s_map);
			InsertServerCommand("nextlevel \"%s\"", s_map);
			ServerExecute();
			return;
		}
	}
	PrintToChat(client, "[%s] Map '%s' not found", chat_pfx,  s_map);
}


public cmd_fn_restartround(client, ArrayList:m_args){
	PrintToChatAll("[%s] Restarting round...", chat_pfx);
	InsertServerCommand("mp_restartround 5");
	ServerExecute();
}

public cmd_fn_restartgame(client, ArrayList:m_args){
	PrintToChatAll("[%s] Restarting game...", chat_pfx);
	InsertServerCommand("mp_restartgame 5");
	ServerExecute();
}

public cmd_fn_switchteams(client, ArrayList:m_args){
	if(g_match_status == LIVE)
		CPrintToChatAll("[%s] {green}Teams will be switched", chat_pfx);
	else
		CPrintToChatAll("[%s] {green}Teams will be switched on round start", chat_pfx);
	InsertServerCommand("mp_switchteams");
	InsertServerCommand("mp_restartround 1");
	ServerExecute();
}

public cmd_fn_pause(client, ArrayList:m_args){
	if(g_paused == PAUSE_STATE:UNPAUSING)
		return;
	if(g_paused == PAUSE_STATE:NOT_PAUSED){
		if(g_match_status == LIVE){
			new String:cname[50];
			GetClientName(client, cname, sizeof(cname));
			CPrintToChatAll("[%s] {green}%s {default}was requested game pause", chat_pfx, cname);
			CPrintToChatAll("[%s] {green}%s ready {default}when your team will be ready", chat_pfx, g_chat_command_prefix);
			pause_game();
		}else{
			PrintToChat(client, "[%s] Match not started yet.", chat_pfx);
		}
	}else{
		if(m_args.Length > 2){
			new String:arg2[32];
			m_args.GetString(2, arg2, sizeof(arg2));
			if(StrEqual("f", arg2) ||
			   StrEqual("force", arg2)){
				new String:cname[50];
				GetClientName(client, cname, sizeof(cname));
				CPrintToChatAll("[%s] {green}%s {default}was requested force unpause", chat_pfx, cname);
				g_paused = PAUSE_STATE:UNPAUSING;
				CreateTimer(1.0, unpause_stage_1);
			}
		}
	}
}


public cmd_fn_ready(client, ArrayList:m_args){
	new ti = GetClientTeam(client);
	if(ti != TEAM_SECURITY && ti != TEAM_INSURGENTS)
		return;
	if(g_team_r[ti])team_set_notready(ti);
	else		team_set_ready(ti);
	check_teams_ready();
}


public cmd_fn_notready(client, ArrayList:m_args){
	new ti = GetClientTeam(client);
	if(ti != TEAM_SECURITY && ti != TEAM_INSURGENTS)
		return;
	if(g_team_r[ti])
		team_set_notready(ti);
}
public team_set_notready(ti){
	new String:team[20];
	if(ti == TEAM_SECURITY)			team = "Security";
	else if(ti == TEAM_INSURGENTS)	team = "Insurgents";
	if(g_match_status == WAITING){ // Gaeme start
		CPrintToChatAll("[%s] {green}%s {default}team {red}NOT {default}ready!", chat_pfx, team);
	}else if(g_match_status == LIVE){
		if(g_paused == PAUSE_STATE:PAUSED){ // Unpause
			CPrintToChatAll("[%s] {green}%s {default}team {red}NOT {default}ready!", chat_pfx, team);
		}
	}
	g_team_r[ti] = false;
}
public team_set_ready(ti){
	new String:team[20];
	if(ti == TEAM_SECURITY)			team = "Security";
	else if(ti == TEAM_INSURGENTS)	team = "Insurgents";
	if(g_match_status == WAITING){
		CPrintToChatAll("[%s] {green}%s {default}team {green}ready!", chat_pfx, team);
	}else if(g_match_status == LIVE){
		if(g_paused == PAUSE_STATE:PAUSED){
			CPrintToChatAll("[%s] {green}%s {default}team {blue}ready!", chat_pfx, team);
		}
	}
	g_team_r[ti] = true;
}
public check_teams_ready(){
	if(g_team_r[TEAM_SECURITY] && g_team_r[TEAM_INSURGENTS]){
		if(g_match_status == WAITING){
			if(g_player_cnt > 1){ // FIXME
				MPINS_Native_SetMatchStatus(STARTING);
			}
		}else if(g_match_status == LIVE){
			if(g_paused == PAUSE_STATE:PAUSED){
				g_team_r[TEAM_SECURITY] = false;
				g_team_r[TEAM_INSURGENTS] = false;
				g_paused = PAUSE_STATE:UNPAUSING;
				CreateTimer(1.0, unpause_stage_1);
			}
		}
	}
}




public cmd_fn_kickspectators(client, ArrayList:m_args){
	new maxplayers = GetMaxClients();
	for (new x = 1; x <= maxplayers ; x++){
		if(!IsClientInGame(x))
			continue;
		if(GetClientTeam(x) != TEAM_SPECTATORS)
			continue;
		KickClient(x, "Spectators was kicked");
	}
}


public cmd_fn_showpassword(client, ArrayList:m_args){
	new Handle:cv_password = FindConVar("sv_password");
	new String:password[100];
	GetConVarString(cv_password, password, sizeof(password));
	CPrintToChat(client, "[%s] Password: {green}%s", chat_pfx, password);
}


public cmd_fn_execcfg(client, ArrayList:m_args){
	if(m_args.Length < 3){
		cmd_fn_listcfg(client, m_args);
		return;
	}
	new String:s_cfg[32];
	m_args.GetString(2, s_cfg, sizeof(s_cfg));
	if(exec_config(s_cfg)){
		CPrintToChatAll("[%s] Loaded \"{green}%s{default}\" config", chat_pfx, s_cfg);
		if(!StrEqual(s_cfg, g_curcfg)){ //Advance map if loaded config differs
			strcopy(g_curcfg, sizeof(g_curcfg), s_cfg);
			map_advance();
		}
	}else{
		CPrintToChat(client, "[%s] Config not found: \"{green}%s{default}\"", chat_pfx, s_cfg);
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
	CPrintToChat(client, "[%s] Current config: {green}%s", chat_pfx, g_curcfg);
	CPrintToChat(client, "[%s] Available configs:%s", chat_pfx, buf_concat);
}


public cmd_fn_status(client, ArrayList:m_args){
	print_status(client);
}
public print_status(client){
	new String:match_status[32];
	if(	g_match_status == WAITING)		match_status = "waiting the teams to get ready";
	else if(g_match_status == STARTING)	match_status = "starting match";
	else if(g_match_status == LIVE_ON_RESTART) match_status = "LOR";
	else if(g_match_status == LIVE)		match_status = "LIVE!";
	else if(g_match_status == STOPING)		match_status = "stoping";
	else if(g_match_status == ENDED)		match_status = "eneded";
	CPrintToChat(client, "[%s] Server config: {green}%s", chat_pfx, g_curcfg);
	CPrintToChat(client, "[%s] Game state: {green}%s", chat_pfx,  match_status);
	if(g_team_r[TEAM_SECURITY])	CPrintToChat(client, "Security: {green}READY");
	else				CPrintToChat(client, "Security: {red}NOT {default}READY");
	if(g_team_r[TEAM_INSURGENTS])	CPrintToChat(client, "Insurgents: {green}READY");
	else				CPrintToChat(client, "Insurgents: {red}NOT {default}READY");
}


public cmd_fn_help(client, ArrayList:m_args){
	CPrintToChat(client, "[%s] Help info printed into {green}console", chat_pfx);
	PrintToConsole(client, "Usage: %s COMMAND [arguments]", g_chat_command_prefix);
	PrintToConsole(client, "Arguments:");
	PrintToConsole(client, " r				   Marks team as ready/unready. After all teams are ready, executes config, generates server password and starts match");
	PrintToConsole(client, " stop			   Stop match");
	PrintToConsole(client, " e CFGNAME		   Exec config");
	PrintToConsole(client, " lc				   List available configs");
	PrintToConsole(client, " cm MAPNAME		   Changing map to MAPNAME");
	PrintToConsole(client, " nm MAPNAME		   Changing nextmap to MAPNAME");
	PrintToConsole(client, " p				   Pause/unpause game");
	PrintToConsole(client, " rg				   Restart game");
	PrintToConsole(client, " rr				   Round restart");
	PrintToConsole(client, " st				   Switch teams");
	PrintToConsole(client, " ks				   Kick spectators");
	PrintToConsole(client, " sp				   Show password");
}


public player_welcome(client){
	if(!GetConVarBool(g_CVAR_pmp_welcome))
		return;
	CPrintToChat(client, "[%s] Welcome on match server", chat_pfx);
	CPrintToChat(client, "[%s] Type {green}%s help {default} for command reference", chat_pfx, g_chat_command_prefix);
	print_status(client);
}






















public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max){
	CreateNative("MPINS_Native_SetMatchStatus", Native_SetMatchStatus);
	//CreateNative("MPINS_Native_GetMatchStatus", Native_GetMatchStatus);
	CreateNative("MPINS_Native_ChatCmd",		Native_ChatCmd);
	FWD_OnMatchStatusChange = CreateGlobalForward("MPINS_OnMatchStatusChange", ET_Hook, Param_Cell, Param_CellByRef);
	FWD_OnChatCmd = CreateGlobalForward("MPINS_OnChatCmd", ET_Hook, Param_Cell, Param_String);
	RegPluginLibrary("MPINS");
	return APLRes_Success;
}

/*
 * Natives
 */
public Native_SetMatchStatus(Handle:plugin, int numParams){
	new MPINS_MatchStatus:new_status;
	new_status = GetNativeCell(1);

	PrintToServer("Changing Status to: '%d'", new_status);
	g_new_match_status = new_status;
	new MPINS_MatchStatus:status;
	PrintToServer("G_match_status: %d", g_match_status);
	if(new_status == g_match_status)
		return false;
	status = MPINS_Native_GetMatchStatus();
	PrintToServer("ActualStatus: %d", status);
	if(new_status != status)
		return false;

	PrintToServer("All ok!");
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

	PrintToServer(">>>>ChatCmd: '%d', '%s'", client, message);


	new Action:act = Plugin_Continue;
	Call_StartForward(FWD_OnChatCmd);
	Call_PushCell(client);
	Call_PushString(message);
	Call_Finish(act);
	//if(act == Plugin_Changed || act == Plugin_Stop)
	//	g_match_status = new_status;
	//return g_match_status;
	return act;
}


public MPINS_MatchStatus:MPINS_Native_GetMatchStatus(){
	new MPINS_MatchStatus:old_status = g_match_status;
	new MPINS_MatchStatus:new_status = g_new_match_status;

	new Action:act = Plugin_Continue;
	Call_StartForward(FWD_OnMatchStatusChange);
	Call_PushCell(old_status);
	Call_PushCellRef(new_status);
	Call_Finish(act);
	if(act == Plugin_Changed || act == Plugin_Stop)
		g_match_status = new_status;
	return g_match_status;
}







public Action:start_stage_1(Handle:timer){
	CPrintToChatAll("{green}%s","=================");
	CPrintToChatAll("{green}%s","Game Ready!");
	CPrintToChatAll("{green}%s","=================");
	CPrintToChatAll("{green}%s","POV demo started?");
	CPrintToChatAll("{green}%s","=================");
	CreateTimer(7.0, start_stage_2);
}

public Action:start_stage_2(Handle:timer){
	if(g_match_status != STARTING) return;
	CPrintToChatAll("{green}%s","-----> 5 <-----");
	CreateTimer(1.0, start_stage_3);
}

public Action:start_stage_3(Handle:timer){
	if(g_match_status != STARTING) return;
	CPrintToChatAll("{green}%s","----> 4 <----");
	CreateTimer(1.0, start_stage_4);
}

public Action:start_stage_4(Handle:timer){
	if(g_match_status != STARTING) return;
	CPrintToChatAll("{green}%s","---> 3 <---");
	CreateTimer(1.0, start_stage_5);
}

public Action:start_stage_5(Handle:timer){
	if(g_match_status != STARTING) return;
	CPrintToChatAll("{green}%s","--> 2 <--");
	CreateTimer(1.0, start_stage_6);
}

public Action:start_stage_6(Handle:timer){
	if(g_match_status != STARTING) return;
	CPrintToChatAll("{green}%s","-> 1 <-");
	CreateTimer(1.0, start_stage_7);
}

public Action:start_stage_7(Handle:timer){
	if(g_match_status != STARTING) return;
	new Handle:cv_password = FindConVar("sv_password");
	new String:password[100];

	CPrintToChatAll("{green}%s","=>--!LIVE ON RESTART!--<=");
	GetConVarString(cv_password, password, sizeof(password));
	CPrintToChatAll("[%s] Password was set to: {green}%s", chat_pfx, password);
	InsertServerCommand("mp_restartgame 1");
	ServerExecute();
	MPINS_Native_SetMatchStatus(LIVE_ON_RESTART);
}






public Action:unpause_stage_1(Handle:timer){
	CPrintToChatAll("{green}%s","-----> UNPAUSING <-----");
	CPrintToChatAll("{green}%s","-----> 5 <-----");
	CreateTimer(1.0, unpause_stage_2);
}
public Action:unpause_stage_2(Handle:timer){
	CPrintToChatAll("{green}%s","----> 4 <----");
	CreateTimer(1.0, unpause_stage_3);
}
public Action:unpause_stage_3(Handle:timer){
	CPrintToChatAll("{green}%s","---> 3 <---");
	CreateTimer(1.0, unpause_stage_4);
}
public Action:unpause_stage_4(Handle:timer){
	CPrintToChatAll("{green}%s","--> 2 <--");
	CreateTimer(1.0, unpause_stage_5);
}
public Action:unpause_stage_5(Handle:timer){
	CPrintToChatAll("{green}%s","-> 1 <-");
	CreateTimer(1.0, unpause_stage_6);
}
public Action:unpause_stage_6(Handle:timer){
	CPrintToChatAll("{green}%s","-> GO! <-");
	InsertServerCommand("unpause");
	ServerExecute();
	g_paused = PAUSE_STATE:NOT_PAUSED;
}
