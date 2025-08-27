#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <skill_detect>
#include <colors>


public Plugin myinfo = {
    name        = "SkillReport",
    author      = "TouchMe",
    description = "Report skeets, levels, highpounces, etc.",
    version     = "build_0000",
    url         = "https://github.com/TouchMe-Inc/l4d2_skill_detect"
}


/*
 * Team.
 */
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

/*
 * Infected Class.
 */
#define SI_CLASS_SMOKER         1
#define SI_CLASS_BOOMER         2
#define SI_CLASS_SPITTER        4
#define SI_CLASS_CHARGER        6


enum ForwardEvent
{
    FE_HeadShot,
    FE_BoomerPop,
    FE_BoomerPopEarly,
    FE_ChargerLevel,
    FE_ChargerLevelHurt,
    FE_HunterDeadstop,
    FE_SkeetSniper,
    FE_SkeetMelee,
    FE_SkeetHurt,
    FE_Skeet,
    FE_TongueCut,
    FE_SmokerSelfClear,
    FE_TankRockSkeeted,
    FE_HunterHighPounce,
    FE_DeathCharge,
    FE_SpecialClear,
    FE_BoomerVomitLanded,
    FE_BunnyHopStreak,
    FE_CarAlarmTriggered,

    FE_Count
};

ConVar g_cvEvent[FE_Count];

char g_szCvar[][] = {
    "sm_skill_report_headshot",           "Enable OnHeadShot messages",
    "sm_skill_report_boomerpop",          "Enable OnBoomerPop messages",
    "sm_skill_report_boomerpopearly",     "Enable OnBoomerPopEarly messages",
    "sm_skill_report_chargerlevel",       "Enable OnChargerLevel messages",
    "sm_skill_report_chargerlevelhurt",   "Enable OnChargerLevelHurt messages",
    "sm_skill_report_hunterdeadstop",     "Enable OnHunterDeadstop messages",
    "sm_skill_report_skeetsniper",        "Enable OnSkeetSniper messages",
    "sm_skill_report_skeetmelee",         "Enable OnSkeetMelee messages",
    "sm_skill_report_skeethurt",          "Enable OnSkeetHurt messages",
    "sm_skill_report_skeet",              "Enable OnSkeet messages",
    "sm_skill_report_tonguecut",          "Enable OnTongueCut messages",
    "sm_skill_report_smokerselfclear",    "Enable OnSmokerSelfClear messages",
    "sm_skill_report_rockskeeted",        "Enable OnTankRockSkeeted messages",
    "sm_skill_report_hunterhighpounce",   "Enable OnHunterHighPounce messages",
    "sm_skill_report_deathcharge",        "Enable OnDeathCharge messages",
    "sm_skill_report_specialclear",       "Enable OnSpecialClear messages",
    "sm_skill_report_boomervomitlanded",  "Enable OnBoomerVomitLanded messages",
    "sm_skill_report_bunnyhopstreak",     "Enable OnBunnyHopStreak messages",
    "sm_skill_report_caralarmtriggered",  "Enable OnCarAlarmTriggered messages"
};

public void OnPluginStart()
{
    for (int i = 0, iIdx=0; i < sizeof(g_szCvar); i += 2)
    {
        g_cvEvent[iIdx++] = CreateConVar(
            g_szCvar[i],    
            "1",     
            g_szCvar[i + 1]
        );
    }
}

public void OnHeadShot(int iAttacker, int iVictim)
{
    if (!GetConVarBool(g_cvEvent[FE_HeadShot])) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim))
        return;

    int zClass = GetInfectedClass(iVictim);
    if (zClass >= SI_CLASS_SMOKER && zClass <= SI_CLASS_CHARGER)
    {
        PrintCenterText(iAttacker, "HEADSHOT!");

        if (!IsFakeClient(iVictim)) {
            PrintCenterText(iVictim, "HEADSHOTED!");
        }   
    }
}

public void OnSkeetSniper(int iAttacker, int iVictim)
{
    if (!GetConVarBool(g_cvEvent[FE_SkeetSniper])) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("{green}★★★{default} Sniper {blue}%N{default} headshot-skeeted {green}%N{default}'s hunter", iAttacker, iVictim);
    } else {
        CPrintToChatAll("{green}☆☆☆{default} Sniper {blue}%N{default} headshot-skeeted a hunter", iAttacker);
    }
}

public void OnSkeetMelee(int iAttacker, int iVictim)
{
    if (!GetConVarBool(g_cvEvent[FE_SkeetMelee])) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("{green}★★★ {blue}%N{default} melee-skeeted {green}%N{default}'s hunter", iAttacker, iVictim);
    } else {
        CPrintToChatAll("{green}☆☆☆ {blue}%N{default} melee-skeeted a hunter", iAttacker);
    }
}

public void OnSkeetHurt(int iAttacker, int iVictim, int iDmg, int iShots)
{
    if (!GetConVarBool(g_cvEvent[FE_SkeetHurt])) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("{green}★ {blue}%N{default} skeeted hurt {green}%N{default}'s hunter for {blue}%d{default} damage in {blue}%d{default} shot%s", iAttacker, iVictim, iDmg, iShots, iShots == 1 ? "" : "s");
    } else {
        CPrintToChatAll("{green}☆ {blue}%N{default} skeeted a hurt hunter for {blue}%d{default} damage in {blue}%d{default} shot%s", iAttacker, iDmg, iShots, iShots == 1 ? "" : "s");
    }
}

public void OnSkeet(int iAttacker, int iVictim, int iShots)
{
    if (!GetConVarBool(g_cvEvent[FE_Skeet])) {
        return;
    }
    
    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        if (iShots == 1) {
            CPrintToChatAll("{green}★★ {blue}%N{default} skeeted {green}%N{default}'s hunter in {blue}%d{default} shot", iAttacker, iVictim, iShots);
        } else {
            CPrintToChatAll("{green}★ {blue}%N{default} skeeted {green}%N{default}'s hunter in {blue}%d{default} shots", iAttacker, iVictim, iShots);
        }
    } else {
        if (iShots == 1) {
            CPrintToChatAll("{green}☆☆ {blue}%N{default} skeeted a hunter in {blue}%d{default} shot", iAttacker, iShots);
        } else {
            CPrintToChatAll("{green}☆ {blue}%N{default} skeeted a hunter in {blue}%d{default} shots", iAttacker, iShots);
        }
    }
}

public void OnBoomerPop(int iAttacker, int iVictim, int iShover, int iShoveCount, float fTimeAlive)
{
    if (!GetConVarBool(g_cvEvent[FE_BoomerPop])) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim)) {
        return;
    }

    if (fTimeAlive > 2.0) {
        return;
    }

    if (IsValidSurvivor(iShover)) {
        if (iAttacker == iShover) {
            if (fTimeAlive < 0.1) {
                if (!IsFakeClient(iVictim)) {
                    CPrintToChatAll("{green}★★★ {blue}%N{default} shoved and popped {green}%N{default}'s boomer {blue}in no time", iAttacker, iVictim);
                } else {
                    CPrintToChatAll("{green}☆☆☆ {blue}%N{default} shoved and popped a boomer {blue}in no time", iAttacker);
                }
            } else {
                if (!IsFakeClient(iVictim)) {
                    CPrintToChatAll("{green}★ {blue}%N{default} shoved and popped {green}%N{default}'s boomer in {blue}%0.1fs", iAttacker, iVictim, fTimeAlive);
                } else {
                    CPrintToChatAll("{green}☆ {blue}%N{default} shoved and popped a boomer in {blue}%0.1fs", iAttacker, fTimeAlive);
                }
            }
        } else {
            if (fTimeAlive < 0.1) {
                if (!IsFakeClient(iVictim)) {
                    CPrintToChatAll("{green}★★★ {blue}%N{default} shoved and {blue}%N{default} popped {green}%N{default}'s boomer {blue}in no time", iShover, iAttacker, iVictim);
                } else {
                    CPrintToChatAll("{green}☆☆☆ {blue}%N{default} shoved and {blue}%N{default} popped a boomer {blue}in no time", iShover, iAttacker);
                }
            } else {
                if (!IsFakeClient(iVictim)) {
                    CPrintToChatAll("{green}★ {blue}%N{default} shoved and {blue}%N{default} popped {green}%N{default}'s boomer in {blue}%0.1fs", iShover, iAttacker, iVictim, fTimeAlive);
                } else {
                    CPrintToChatAll("{green}☆ {blue}%N{default} shoved and {blue}%N{default} popped a boomer in {blue}%0.1fs", iShover, iAttacker, fTimeAlive);
                }
            }
        }
    } else {
        if (fTimeAlive < 0.1) {
            if (!IsFakeClient(iVictim)) {
                CPrintToChatAll("{green}★★★ {blue}%N{default} shut down {green}%N{default}'s boomer {blue}in no time", iAttacker, iVictim);
            } else {
                CPrintToChatAll("{green}☆☆☆ {blue}%N{default} shut down a boomer {blue}in no time", iAttacker);
            }
        } else {
            if (!IsFakeClient(iVictim)) {
                CPrintToChatAll("{green}★ {blue}%N{default} shut down {green}%N{default}'s boomer in {blue}%0.1fs", iAttacker, iVictim, fTimeAlive);
            } else {
                CPrintToChatAll("{green}☆ {blue}%N{default} shut down a boomer in {blue}%0.1fs", iAttacker, fTimeAlive);
            }
        }
    }
}

public void OnBoomerPopEarly(int iAttacker, int iVictim, int iShover)
{
    if (!GetConVarBool(g_cvEvent[FE_BoomerPopEarly])) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim) || !IsValidSurvivor(iShover))
        return;

    if (iAttacker == iShover) {
        if (!IsFakeClient(iVictim)) {
            CPrintToChatAll("{green}☠ {blue}%N{default} shoved {green}%N{default}'s boomer but popped it too early", iAttacker, iVictim);
        } else {
            CPrintToChatAll("{green}☠ {blue}%N{default} shoved a boomer but popped it too early", iAttacker);
        }
    } else {
        if (!IsFakeClient(iVictim)) {
            CPrintToChatAll("{green}☠ {blue}%N{default} shoved {green}%N{default}'s boomer but {blue}%N{default} popped it too early", iShover, iVictim, iAttacker);
        } else {
            CPrintToChatAll("{green}☠ {blue}%N{default} shoved a boomer but {blue}%N{default} popped it too early", iShover, iVictim);
        }
    }
}

public void OnChargerLevel(int iAttacker, int iVictim)
{
    if (!GetConVarBool(g_cvEvent[FE_ChargerLevel])) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim)) {
        return;
    }

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("{green}★★★ {blue}%N{default} leveled {green}%N{default}'s charger", iAttacker, iVictim);
    } else {
        CPrintToChatAll("{green}☆☆☆ {blue}%N{default} leveled a charger", iAttacker);
    }
}

public void OnChargerLevelHurt(int iAttacker, int iVictim, int iDmg)
{
    if (!GetConVarBool(g_cvEvent[FE_ChargerLevelHurt])) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("{green}★ {blue}%N{default} leveled hurt {green}%N{default}'s charger for {blue}%d{default} damage", iAttacker, iVictim, iDmg);
    } else {
        CPrintToChatAll("{green}☆ {blue}%N{default} leveled a hurt charger for {blue}%d{default} damage", iAttacker, iDmg);
    }
}

public void OnHunterDeadstop(int iAttacker, int iVictim)
{
    if (!GetConVarBool(g_cvEvent[FE_HunterDeadstop])) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim)) {
        return;
    }

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("{green}★ {blue}%N{default} deadstopped {green}%N{default}'s hunter", iAttacker, iVictim);
    } else {
        CPrintToChatAll("{green}☆ {blue}%N{default} deadstopped a hunter", iAttacker);
    }
}

public void OnTongueCut(int iAttacker, int iVictim)
{
    if (!GetConVarBool(g_cvEvent[FE_TongueCut])) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim)) {
        return;
    }

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("{green}★★ {blue}%N{default} cut {green}%N{default}'s smoker tongue", iAttacker, iVictim);
    } else {
        CPrintToChatAll("{green}☆☆ {blue}%N{default} cut a smoker tongue", iAttacker);
    }
}

public void OnSmokerSelfClear(int iAttacker, int iVictim, bool bWithShove)
{
    if (!GetConVarBool(g_cvEvent[FE_SmokerSelfClear])) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim)) {
        return;
    }

    if (!IsFakeClient(iVictim)) {
        if (bWithShove) {
            CPrintToChatAll("{green}★★ {blue}%N{default} shoved {green}%N{default}'s smoker while being capped", iAttacker, iVictim);
        } else {
            CPrintToChatAll("{green}★★ {blue}%N{default} killed {green}%N{default}'s smoker while being capped", iAttacker, iVictim);
        }
    } else {
        if (bWithShove) {
            CPrintToChatAll("{green}☆☆ {blue}%N{default} shoved a smoker while being capped", iAttacker);
        } else {
            CPrintToChatAll("{green}☆☆ {blue}%N{default} killed a smoker while being capped", iAttacker);
        }
    }
}

public void OnTankRockSkeeted(int iAttacker, int iVictim)
{
    if (!GetConVarBool(g_cvEvent[FE_TankRockSkeeted])) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim)) {
        return;
    }

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("{green}★★ {blue}%N{default} skeeted {green}%N{default}'s tank rock", iAttacker, iVictim);
    } else {
        CPrintToChatAll("{green}☆☆ {blue}%N{default} skeeted a tank rock", iAttacker);
    }
}

public void OnHunterHighPounce(int iAttacker, int iVictim, int iActualDmg, float fCalculatedDmg, float fHeight, bool bPlayerIncapped)
{
    if (!GetConVarBool(g_cvEvent[FE_HunterHighPounce])) {
        return;
    }

    if (!IsValidInfected(iAttacker) || IsFakeClient(iAttacker) || !IsValidSurvivor(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        if (RoundToFloor(fCalculatedDmg) == 25) {
            CPrintToChatAll("{green}★★★ {red}%N{default} high-pounced {green}%N{default} (Damage: {red}%i{default})", iAttacker, iVictim, RoundToFloor(fCalculatedDmg));
        } else if (RoundToFloor(fCalculatedDmg) >= 20) {
            CPrintToChatAll("{green}★★ {red}%N{default} high-pounced {green}%N{default} (Damage: {red}%i{default})", iAttacker, iVictim, RoundToFloor(fCalculatedDmg));
        } else if (RoundToFloor(fCalculatedDmg) >= 15) {
            CPrintToChatAll("{green}★ {red}%N{default} high-pounced {green}%N{default} (Damage: {red}%i{default})", iAttacker, iVictim, RoundToFloor(fCalculatedDmg));
        }
    } else {
        if (RoundToFloor(fCalculatedDmg) == 25) {
            CPrintToChatAll("{green}☆☆☆ {red}%N{default} high-pounced {green}%N{default} (Damage: {red}%i{default})", iAttacker, iVictim, RoundToFloor(fCalculatedDmg));
        } else if (RoundToFloor(fCalculatedDmg) >= 20) {
            CPrintToChatAll("{green}☆☆ {red}%N{default} high-pounced {green}%N{default} (Damage: {red}%i{default})", iAttacker, iVictim, RoundToFloor(fCalculatedDmg));
        } else if (RoundToFloor(fCalculatedDmg) >= 15) {
            CPrintToChatAll("{green}☆ {red}%N{default} high-pounced {green}%N{default} (Damage: {red}%i{default})", iAttacker, iVictim, RoundToFloor(fCalculatedDmg));
        }
    }
}

public void OnDeathCharge(int iAttacker, int iVictim, float fHeight, float fDistance, bool bCarried)
{
    if (!GetConVarBool(g_cvEvent[FE_DeathCharge])) {
        return;
    }

    if (!IsValidInfected(iAttacker) || IsFakeClient(iAttacker) || !IsValidSurvivor(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("{green}★★★ {red}%N{default} death-charged {green}%N{default}%s", iAttacker, iVictim, bCarried ? "" : " by bowling");
    } else {
        CPrintToChatAll("{green}☆☆☆ {red}%N{default} death-charged {green}%N{default}%s", iAttacker, iVictim, bCarried ? "" : " by bowling");
    }
}

public void OnSpecialClear(int iAttacker, int iVictim, int iPinVictim, int zClass, float fClearTimeA, float fClearTimeB, bool bWithShove)
{
    if (!GetConVarBool(g_cvEvent[FE_DeathCharge])) {
        return;
    }

    static const char szInfCls[][] = {
        "none",
        "smoker",
        "boomer",
        "hunter",
        "spitter",
        "jockey",
        "charger",
        "witch",
        "tank"
    };

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim) || !IsValidSurvivor(iPinVictim))
        return;

    // sanity check:
    if (fClearTimeA < 0 && fClearTimeA != -1.0)
        fClearTimeA = 0.0;

    if (fClearTimeB < 0 && fClearTimeB != -1.0)
        fClearTimeB = 0.0;

    if (iAttacker == iPinVictim)
        return;

    float fClearTime = fClearTimeA;

    if (zClass == SI_CLASS_SMOKER || zClass == SI_CLASS_CHARGER)
        fClearTime = fClearTimeB;

    if (fClearTime == -1.0)
        return;

    if (fClearTime <= 0.01) {
        if (!IsFakeClient(iVictim)) {
            CPrintToChatAll("{green}★★★ {blue}%N{default} saved {blue}%N{default} from {green}%N{default}'s %s {blue}in no time", iAttacker, iPinVictim, iVictim, szInfCls[zClass]);
        } else {
            CPrintToChatAll("{green}☆☆☆ {blue}%N{default} saved {blue}%N{default} from a %s {blue}in no time", iAttacker, iPinVictim, szInfCls[zClass]);
        }
    } else if (fClearTime <= 0.40) {
        if (!IsFakeClient(iVictim)) {
            CPrintToChatAll("{green}★★ {blue}%N{default} insta-cleared {blue}%N{default} from {green}%N{default}'s %s in {blue}%.2fs", iAttacker, iPinVictim, iVictim, szInfCls[zClass], fClearTime);
        } else {
            CPrintToChatAll("{green}☆☆ {blue}%N{default} insta-cleared {blue}%N{default} from a %s in {blue}%.2fs", iAttacker, iPinVictim, szInfCls[zClass], fClearTime);
        }
    } else if (fClearTime <= 0.75) {
        if (!IsFakeClient(iVictim)) {
            CPrintToChatAll("{green}★ {blue}%N{default} insta-cleared {blue}%N{default} from {green}%N{default}'s %s in {blue}%.2fs", iAttacker, iPinVictim, iVictim, szInfCls[zClass], fClearTime);
        } else {
            CPrintToChatAll("{green}☆ {blue}%N{default} insta-cleared {blue}%N{default} from a %s in {blue}%.2fs", iAttacker, iPinVictim, szInfCls[zClass], fClearTime);
        }
    }
}

public void OnBoomerVomitLanded(int iAttacker, int iBoomCount)
{
    if (!GetConVarBool(g_cvEvent[FE_BoomerVomitLanded])) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker)) {
        return;
    }

    if (iBoomCount == 4)
        CPrintToChatAll("{green}★★★ {red}%N{default} vomited all {olive}4{default} survivors", iAttacker);
}

public void OnBunnyHopStreak(int iSurvivor, int iStreak, float fMaxVelocity)
{
    if (!GetConVarBool(g_cvEvent[FE_BunnyHopStreak])) {
        return;
    }

    if (!IsValidSurvivor(iSurvivor) || IsFakeClient(iSurvivor))
        return;

    if (fMaxVelocity < 250.0)
        return;

    if (iStreak > 8) {
        CPrintToChatAll("{green}★★★ {blue}%N{default} got {blue}%d{default} bunnyhops in a row. Top speed: {blue}%.01f", iSurvivor, iStreak, fMaxVelocity);
    } else if (iStreak > 5) {
        CPrintToChatAll("{green}★★ {blue}%N{default} got {blue}%d{default} bunnyhops in a row. Top speed: {blue}%.01f", iSurvivor, iStreak, fMaxVelocity);
    } else if (iStreak > 2) {
        CPrintToChatAll("{green}★ {blue}%N{default} got {blue}%d{default} bunnyhops in a row. Top speed: {blue}%.01f", iSurvivor, iStreak, fMaxVelocity);
    }
}

public void OnCarAlarmTriggered(int iSurvivor)
{
    if (!GetConVarBool(g_cvEvent[FE_CarAlarmTriggered])) {
        return;
    }

    if (!IsValidSurvivor(iSurvivor) || IsFakeClient(iSurvivor))
        return;

    CPrintToChatAll("{green}☠ {blue}%N{default} triggered an alarm", iSurvivor);
}

/**
 * Checks whether the player is a Survivor.
 *
 * @param iClient   Client index.
 * @return          true if the client is on the Survivor team, otherwise false.
 */
bool IsClientSurvivor(int iClient) {
    return (GetClientTeam(iClient) == TEAM_SURVIVOR);
}

/**
 * Checks whether the player is Infected.
 *
 * @param iClient   Client index.
 * @return          true if the client is on the Infected team, otherwise false.
 */
bool IsClientInfected(int iClient) {
    return (GetClientTeam(iClient) == TEAM_INFECTED);
}

/**
 * Validates whether the client index is within a valid range.
 *
 * @param iClient   Client index.
 * @return          true if the client index is valid, otherwise false.
 */
bool IsValidClient(int iClient) {
    return (iClient > 0 && iClient <= MaxClients);
}

bool IsValidSurvivor(int iClient) {
    return IsValidClient(iClient) && IsClientInGame(iClient) && IsClientSurvivor(iClient);
}

/**
 * Checks whether the client is a valid in-game Survivor.
 *
 * @param iClient   Client index.
 * @return          true if the client exists, is in-game, and is a Survivor.
 */
bool IsValidInfected(int iClient) {
    return IsValidClient(iClient) && IsClientInGame(iClient) && IsClientInfected(iClient);
}

/**
 * Retrieves the zombie class for an Infected player.
 *
 * @param iClient   Client index of the Infected player.
 * @return          Integer ID of the zombie class (see m_zombieClass constants).
 */
int GetInfectedClass(int iClient) {
    return GetEntProp(iClient, Prop_Send, "m_zombieClass");
}