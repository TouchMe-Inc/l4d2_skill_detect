#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <skill_detect>
#include <colors>


public Plugin myinfo = {
    name        = "SkillReport",
    author      = "TouchMe",
    description = "Report skeets, levels, highpounces, etc.",
    version     = "build_0001",
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


#define IsEventEnabled(%1) g_bEventEnabled[%1]


enum
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

enum struct EventCvarInfo
{
    char name[64];
    char desc[128];
}

EventCvarInfo g_cvEventInfo[FE_Count] = {
    { "sm_skill_report_headshot",          "Enable OnHeadShot messages" },
    { "sm_skill_report_boomerpop",         "Enable OnBoomerPop messages" },
    { "sm_skill_report_boomerpopearly",    "Enable OnBoomerPopEarly messages" },
    { "sm_skill_report_chargerlevel",      "Enable OnChargerLevel messages" },
    { "sm_skill_report_chargerlevelhurt",  "Enable OnChargerLevelHurt messages" },
    { "sm_skill_report_hunterdeadstop",    "Enable OnHunterDeadstop messages" },
    { "sm_skill_report_skeetsniper",       "Enable OnSkeetSniper messages" },
    { "sm_skill_report_skeetmelee",        "Enable OnSkeetMelee messages" },
    { "sm_skill_report_skeethurt",         "Enable OnSkeetHurt messages" },
    { "sm_skill_report_skeet",             "Enable OnSkeet messages" },
    { "sm_skill_report_tonguecut",         "Enable OnTongueCut messages" },
    { "sm_skill_report_smokerselfclear",   "Enable OnSmokerSelfClear messages" },
    { "sm_skill_report_rockskeeted",       "Enable OnTankRockSkeeted messages" },
    { "sm_skill_report_hunterhighpounce",  "Enable OnHunterHighPounce messages" },
    { "sm_skill_report_deathcharge",       "Enable OnDeathCharge messages" },
    { "sm_skill_report_specialclear",      "Enable OnSpecialClear messages" },
    { "sm_skill_report_boomervomitlanded", "Enable OnBoomerVomitLanded messages" },
    { "sm_skill_report_bunnyhopstreak",    "Enable OnBunnyHopStreak messages" },
    { "sm_skill_report_caralarmtriggered", "Enable OnCarAlarmTriggered messages" }
};

ConVar g_cvEvent[FE_Count];
bool   g_bEventEnabled[FE_Count];


public void OnPluginStart()
{
    LoadTranslations("skill_report.phrases");

    for (int i = 0; i < view_as<int>(FE_Count); i++)
    {
        g_cvEvent[i] = CreateConVar(
            g_cvEventInfo[i].name,
            "1",
            g_cvEventInfo[i].desc
        );
        g_cvEvent[i].AddChangeHook(OnEventConVarChanged);
        g_bEventEnabled[i] = g_cvEvent[i].BoolValue;
    }
}

public void OnEventConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    for (int i = 0; i < view_as<int>(FE_Count); i++)
    {
        if (convar == g_cvEvent[i]) {
            g_bEventEnabled[i] = convar.BoolValue;
            return;
        }
    }
}

public void OnHeadShot(int iAttacker, int iVictim)
{
    if (!IsEventEnabled(FE_HeadShot)) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim))
        return;

    int zClass = GetInfectedClass(iVictim);
    if (zClass >= SI_CLASS_SMOKER && zClass <= SI_CLASS_CHARGER)
    {
        PrintCenterText(iAttacker, "%T", "HEADSHOT", iAttacker);

        if (!IsFakeClient(iVictim)) {
            PrintCenterText(iVictim, "%T", "HEADSHOTED", iVictim);
        }
    }
}

public void OnSkeetSniper(int iAttacker, int iVictim)
{
    if (!IsEventEnabled(FE_SkeetSniper)) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim)) {
        return;
    }

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("%t%t", "MEDIUM", "SKEET_SNIPER", iAttacker, iVictim);
    } else {
        CPrintToChatAll("%t%t", "MEDIUM", "SKEET_SNIPER_BOT", iAttacker);
    }
}

public void OnSkeetMelee(int iAttacker, int iVictim)
{
    if (!IsEventEnabled(FE_SkeetMelee)) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("%t%t", "HARD", "SKEET_MELEE", iAttacker, iVictim);
    } else {
        CPrintToChatAll("%t%t", "HARD", "SKEET_MELEE_BOT", iAttacker);
    }
}

public void OnSkeetHurt(int iAttacker, int iVictim, int iDmg, int iShots)
{
    if (!IsEventEnabled(FE_SkeetHurt)) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim)) {
        return;
    }

    if (!IsFakeClient(iVictim)) {
        if (iShots == 1) {
            CPrintToChatAll("%t%t", "EASY", "SKEET_HURT_ONE_SHOT", iAttacker, iVictim, iDmg);
        } else {
            CPrintToChatAll("%t%t", "EASY", "SKEET_HURT", iAttacker, iVictim, iDmg, iShots);
        }
    } else {
        if (iShots == 1) {
            CPrintToChatAll("%t%t", "EASY", "SKEET_HURT_ONE_SHOT_BOT", iAttacker, iDmg);
        } else {
            CPrintToChatAll("%t%t", "EASY", "SKEET_HURT_BOT", iAttacker, iDmg, iShots);
        }
    }
}

public void OnSkeet(int iAttacker, int iVictim, int iShots)
{
    if (!IsEventEnabled(FE_Skeet)) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim)) {
        return;
    }

    if (!IsFakeClient(iVictim)) {
        if (iShots == 1) {
            CPrintToChatAll("%t%t", "MEDIUM", "SKEET_ONE_SHOT", iAttacker, iVictim);
        } else {
            CPrintToChatAll("%t%t", "EASY", "SKEET", iAttacker, iVictim, iShots);
        }
    } else {
        if (iShots == 1) {
            CPrintToChatAll("%t%t", "MEDIUM", "SKEET_ONE_SHOT_BOT", iAttacker);
        } else {
            CPrintToChatAll("%t%t", "EASY", "SKEET_BOT", iAttacker, iShots);
        }
    }
}

public void OnBoomerPop(int iAttacker, int iVictim, int iShover, int iShoveCount, float fTimeAlive)
{
    if (!IsEventEnabled(FE_BoomerPop)) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim)) {
        return;
    }

    if (fTimeAlive > 2.0) {
        return;
    }

    bool bInstant = (fTimeAlive < 0.1);
    bool bVictimBot = IsFakeClient(iVictim);

    if (IsValidSurvivor(iShover)) {
        if (iAttacker == iShover) {
            if (bInstant) {
                if (!bVictimBot) {
                    CPrintToChatAll("%t%t", "HARD", "BOOMER_POP_SELF_INSTANT", iAttacker, iVictim);
                } else {
                    CPrintToChatAll("%t%t", "HARD", "BOOMER_POP_SELF_INSTANT_BOT", iAttacker);
                }
            } else {
                if (!bVictimBot) {
                    CPrintToChatAll("%t%t", "EASY", "BOOMER_POP_SELF", iAttacker, iVictim, fTimeAlive);
                } else {
                    CPrintToChatAll("%t%t", "EASY", "BOOMER_POP_SELF_BOT", iAttacker, fTimeAlive);
                }
            }
        } else {
            if (bInstant) {
                if (!bVictimBot) {
                    CPrintToChatAll("%t%t", "HARD", "BOOMER_POP_OTHER_INSTANT", iShover, iAttacker, iVictim);
                } else {
                    CPrintToChatAll("%t%t", "HARD", "BOOMER_POP_OTHER_INSTANT_BOT", iShover, iAttacker);
                }
            } else {
                if (!bVictimBot) {
                    CPrintToChatAll("%t%t", "EASY", "BOOMER_POP_OTHER", iShover, iAttacker, iVictim, fTimeAlive);
                } else {
                    CPrintToChatAll("%t%t", "EASY", "BOOMER_POP_OTHER_BOT", iShover, iAttacker, fTimeAlive);
                }
            }
        }
    } else {
        if (bInstant) {
            if (!bVictimBot) {
                CPrintToChatAll("%t%t", "HARD", "BOOMER_POP_SHUTDOWN_INSTANT", iAttacker, iVictim);
            } else {
                CPrintToChatAll("%t%t", "HARD", "BOOMER_POP_SHUTDOWN_INSTANT_BOT", iAttacker);
            }
        } else {
            if (!bVictimBot) {
                CPrintToChatAll("%t%t", "EASY", "BOOMER_POP_SHUTDOWN", iAttacker, iVictim, fTimeAlive);
            } else {
                CPrintToChatAll("%t%t", "EASY", "BOOMER_POP_SHUTDOWN_BOT", iAttacker, fTimeAlive);
            }
        }
    }
}

public void OnBoomerPopEarly(int iAttacker, int iVictim, int iShover)
{
    if (!IsEventEnabled(FE_BoomerPopEarly)) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim) || !IsValidSurvivor(iShover)) {
        return;
    }

    if (iAttacker == iShover) {
        if (!IsFakeClient(iVictim)) {
            CPrintToChatAll("%t%t", "BADASS", "BOOMER_POP_EARLY_SELF", iAttacker, iVictim);
        } else {
            CPrintToChatAll("%t%t", "BADASS", "BOOMER_POP_EARLY_SELF_BOT", iAttacker);
        }
    } else {
        if (!IsFakeClient(iVictim)) {
            CPrintToChatAll("%t%t", "BADASS", "BOOMER_POP_EARLY_OTHER", iShover, iVictim, iAttacker);
        } else {
            CPrintToChatAll("%t%t", "BADASS", "BOOMER_POP_EARLY_OTHER_BOT", iShover, iAttacker);
        }
    }
}

public void OnChargerLevel(int iAttacker, int iVictim)
{
    if (!IsEventEnabled(FE_ChargerLevel)) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim)) {
        return;
    }

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("%t%t", "HARD", "CHARGER_LEVEL", iAttacker, iVictim);
    } else {
        CPrintToChatAll("%t%t", "HARD", "CHARGER_LEVEL_BOT", iAttacker);
    }
}

public void OnChargerLevelHurt(int iAttacker, int iVictim, int iDmg)
{
    if (!IsEventEnabled(FE_ChargerLevelHurt)) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("%t%t", "EASY", "CHARGER_LEVEL_HURT", iAttacker, iVictim, iDmg);
    } else {
        CPrintToChatAll("%t%t", "EASY", "CHARGER_LEVEL_HURT_BOT", iAttacker, iDmg);
    }
}

public void OnHunterDeadstop(int iAttacker, int iVictim)
{
    if (!IsEventEnabled(FE_HunterDeadstop)) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim)) {
        return;
    }

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("%t%t", "EASY", "HUNTER_DEADSTOP", iAttacker, iVictim);
    } else {
        CPrintToChatAll("%t%t", "EASY", "HUNTER_DEADSTOP_BOT", iAttacker);
    }
}

public void OnTongueCut(int iAttacker, int iVictim)
{
    if (!IsEventEnabled(FE_TongueCut)) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim)) {
        return;
    }

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("%t%t", "MEDIUM", "TONGUE_CUT", iAttacker, iVictim);
    } else {
        CPrintToChatAll("%t%t", "MEDIUM", "TONGUE_CUT_BOT", iAttacker);
    }
}

public void OnSmokerSelfClear(int iAttacker, int iVictim, bool bWithShove)
{
    if (!IsEventEnabled(FE_SmokerSelfClear)) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim)) {
        return;
    }

    if (!IsFakeClient(iVictim)) {
        if (bWithShove) {
            CPrintToChatAll("%t%t", "MEDIUM", "SMOKER_SELF_CLEAR_SHOVE", iAttacker, iVictim);
        } else {
            CPrintToChatAll("%t%t", "MEDIUM", "SMOKER_SELF_CLEAR_KILL", iAttacker, iVictim);
        }
    } else {
        if (bWithShove) {
            CPrintToChatAll("%t%t", "MEDIUM", "SMOKER_SELF_CLEAR_SHOVE_BOT", iAttacker);
        } else {
            CPrintToChatAll("%t%t", "MEDIUM", "SMOKER_SELF_CLEAR_KILL_BOT", iAttacker);
        }
    }
}

public void OnTankRockSkeeted(int iAttacker, int iVictim)
{
    if (!IsEventEnabled(FE_TankRockSkeeted)) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim)) {
        return;
    }

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("%t%t", "MEDIUM", "TANK_ROCK_SKEETED", iAttacker, iVictim);
    } else {
        CPrintToChatAll("%t%t", "MEDIUM", "TANK_ROCK_SKEETED_BOT", iAttacker);
    }
}

public void OnHunterHighPounce(int iAttacker, int iVictim, int iActualDmg, float fCalculatedDmg, float fHeight, bool bPlayerIncapped)
{
    if (!IsEventEnabled(FE_HunterHighPounce)) {
        return;
    }

    if (!IsValidInfected(iAttacker) || IsFakeClient(iAttacker) || !IsValidSurvivor(iVictim))
        return;

    int iDamage = RoundToFloor(fCalculatedDmg);

    if (iDamage == 25) {
        if (!IsFakeClient(iVictim)) {
            CPrintToChatAll("%t%t", "HARD", "HUNTER_HIGH_POUNCE", iAttacker, iVictim, iDamage);
        } else {
            CPrintToChatAll("%t%t", "HARD", "HUNTER_HIGH_POUNCE_BOT", iAttacker, iVictim, iDamage);
        }
    } else if (iDamage >= 20) {
        if (!IsFakeClient(iVictim)) {
            CPrintToChatAll("%t%t", "MEDIUM", "HUNTER_HIGH_POUNCE", iAttacker, iVictim, iDamage);
        } else {
            CPrintToChatAll("%t%t", "MEDIUM", "HUNTER_HIGH_POUNCE_BOT", iAttacker, iVictim, iDamage);
        }
    } else if (iDamage >= 15) {
        if (!IsFakeClient(iVictim)) {
            CPrintToChatAll("%t%t", "EASY", "HUNTER_HIGH_POUNCE", iAttacker, iVictim, iDamage);
        } else {
            CPrintToChatAll("%t%t", "EASY", "HUNTER_HIGH_POUNCE_BOT", iAttacker, iVictim, iDamage);
        }
    }
} 

public void OnDeathCharge(int iAttacker, int iVictim, float fHeight, float fDistance, bool bCarried)
{
    if (!IsEventEnabled(FE_DeathCharge)) {
        return;
    }

    if (!IsValidInfected(iAttacker) || IsFakeClient(iAttacker) || !IsValidSurvivor(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        if (bCarried) {
            CPrintToChatAll("%t%t", "HARD", "DEATH_CHARGE", iAttacker, iVictim);
        } else {
            CPrintToChatAll("%t%t", "HARD", "DEATH_CHARGE_BOWLING", iAttacker, iVictim);
        }
    } else {
        if (bCarried) {
            CPrintToChatAll("%t%t", "HARD", "DEATH_CHARGE_BOT", iAttacker);
        } else {
            CPrintToChatAll("%t%t", "HARD", "DEATH_CHARGE_BOWLING_BOT", iAttacker);
        }
    }
}

public void OnSpecialClear(int iAttacker, int iVictim, int iPinVictim, int zClass, float fClearTimeA, float fClearTimeB, bool bWithShove)
{
    if (!IsEventEnabled(FE_SpecialClear)) {
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

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim) || !IsValidSurvivor(iPinVictim)) {
        return;
    }

    if (iAttacker == iPinVictim)
        return;

    // sanity check:
    if (fClearTimeA < 0 && fClearTimeA != -1.0)
        fClearTimeA = 0.0;

    if (fClearTimeB < 0 && fClearTimeB != -1.0)
        fClearTimeB = 0.0;

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
    if (!IsEventEnabled(FE_BoomerVomitLanded)) {
        return;
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker)) {
        return;
    }

    if (iBoomCount == 4) {
        CPrintToChatAll("%t%t", "HARD", "VOMITED_ALL", iAttacker);
    }
}

public void OnBunnyHopStreak(int iSurvivor, int iStreak, float fMaxVelocity)
{
    if (!IsEventEnabled(FE_BunnyHopStreak)) {
        return;
    }

    if (!IsValidSurvivor(iSurvivor) || IsFakeClient(iSurvivor)) {
        return;
    }

    if (fMaxVelocity < 250.0) {
        return;
    }

    if (iStreak > 8) {
        CPrintToChatAll("%t%t", "HARD", "BUNNYHOP_STREAK", iSurvivor, iStreak, fMaxVelocity);
    } else if (iStreak > 5) {
        CPrintToChatAll("%t%t", "MEDIUM", "BUNNYHOP_STREAK", iSurvivor, iStreak, fMaxVelocity);
    } else if (iStreak > 2) {
        CPrintToChatAll("%t%t", "EASY", "BUNNYHOP_STREAK", iSurvivor, iStreak, fMaxVelocity);
    }
}

public void OnCarAlarmTriggered(int iSurvivor)
{
    if (!IsEventEnabled(FE_CarAlarmTriggered)) {
        return;
    }

    if (!IsValidSurvivor(iSurvivor) || IsFakeClient(iSurvivor)) {
        return;
    }

    CPrintToChatAll("%t%t", "BADASS", "CAR_ALARM_TRIGGERED", iSurvivor);
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
bool IsValidClientIndex(int iClient) {
    return (iClient > 0 && iClient <= MaxClients);
}

bool IsValidSurvivor(int iClient) {
    return IsValidClientIndex(iClient) && IsClientInGame(iClient) && IsClientSurvivor(iClient);
}

/**
 * Checks whether the client is a valid in-game Survivor.
 *
 * @param iClient   Client index.
 * @return          true if the client exists, is in-game, and is a Survivor.
 */
bool IsValidInfected(int iClient) {
    return IsValidClientIndex(iClient) && IsClientInGame(iClient) && IsClientInfected(iClient);
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
