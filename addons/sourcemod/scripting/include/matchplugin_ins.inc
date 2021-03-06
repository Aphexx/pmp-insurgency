#include <sourcemod>
#include <regex>
#include <sdktools_gamerules>

#if defined _matchplugin_ins_included
 #endinput
#endif
#define _matchplugin_ins_included

enum TEAM{
	NONE,
	SPECTATORS,
	SECURITY,
	INSURGENTS
};

#define VOTE_OPT_YES "yes"
#define VOTE_OPT_NO  "no"
#define CHAT_PFX     "MP"

enum MPINS_MatchStatus{
	NONE,
	WAITING,
	STARTING,
	LIVE_ON_RESTART,
	LIVE,
	STOPING,
	ENDED,
	MODULE_HANDLED
};

native MPINS_Native_RegCmd(String:cmd_alias[], String:cmd_fn_name[], Handle:cmd_plugin);
native MPINS_Native_RegVote(String:vote_name[], String:vote_fn_name[], Handle:vote_plugin);

native MPINS_Native_SetWaitForReadiness(const String:rdy_for[], const String:rdy_description[]);
native MPINS_Native_UnsetWaitForReadiness(const String:rdy_for[]);
native MPINS_Native_GetCurrentReadinessFor(const String:rdy_for[], str_size);
native bool:MPINS_Native_GetTeamReadiness(TEAM:team);
native MPINS_Native_SetTeamReadiness(TEAM:team, bool:rdy);
forward Action:MPINS_OnTeamReady(TEAM:team, const String:rdy_for[], const String:rdy_descr[]);
forward Action:MPINS_OnTeamUnready(TEAM:team, const String:rdy_for[], const String:rdy_descr[]);
forward Action:MPINS_OnAllTeamsReady(const String:rdy_for[], const String:rdy_descr[]);



native bool:MPINS_Native_VoteStart(client, const String:vote_name[], const String:vote_tittle[], const String:vote_descr[]);
native MPINS_Native_VoteGetParams(String:vote_name[], name_size, String:vote_tittle[], tittle_size);

native Action:MPINS_Native_ChatCmd(client, const String:message[], &Action:act);
forward Action:MPINS_Native_OnChatCmd(client, const String:message[]);


native bool:MPINS_Native_SetMatchStatus(MPINS_MatchStatus:new_status);
native MPINS_Native_GetMatchStatus(&MPINS_MatchStatus:status);

forward Action:MPINS_OnMatchStatusChange(MPINS_MatchStatus:old_status, &MPINS_MatchStatus:new_status);

forward MPINS_OnHelpCalled(client);


native MPINS_Native_SetHostnamePostfix(const String:postfix[]);





stock PrintToChatTeam(TEAM:team, String:msg[], String:...){
	decl String:FormattedMessage[512];
	VFormat(FormattedMessage, sizeof(FormattedMessage), msg, 3);
	for(new i = 1; i <= MaxClients; i++){
		if(!(IsClientInGame(i) && !IsFakeClient(i)))
		    continue;
		if(TEAM:GetClientTeam(i) == team){
			PrintToChat(i, FormattedMessage);
		}
	}
}


stock bool:IsValidClient(client, bool:nobots = true){
	if(client <= 0 || client > MaxClients || !IsClientConnected(client))
		return false;
	return IsClientInGame(client);
}

stock InsGetTeamName(TEAM:team, String:team_n[], size){
	if(team == INSURGENTS)		strcopy(team_n, size+1, "Insurgency");
	else if(team == SECURITY)	strcopy(team_n, size+1, "Security");
	else if(team == SPECTATORS)	strcopy(team_n, size+1, "Spectators");
	else strcopy(team_n, size+1, "NONE");
}
stock bool:IsGenericAdmin(client){
	return GetAdminFlag(GetUserAdmin(client), Admin_Generic);
}

stock tag_append(const String:tag[]){
	new ConVar:sv_tags = FindConVar("sv_tags");
	new String:rpatt[32];
	decl String:tags[400];
	decl String:newTags[400];
	new Regex:rtag;
	Format(rpatt, sizeof(rpatt), "(^|,)%s(,|$)", tag);
	rtag = new Regex(rpatt, PCRE_CASELESS);
	sv_tags.GetString(tags, sizeof(tags));
	if(!rtag.Match(tags)){
		Format(newTags, sizeof(newTags), "%s,%s", tags, tag);
		sv_tags.SetString(newTags);
	}
}


stock GameRules_GetGameState(){
    return GameRules_GetProp("m_iGameState");
}