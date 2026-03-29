std = "lua51"
max_line_length = false

exclude_files = {
    ".luacheckrc",
    "Libs/",
}

ignore = {
    "212/self", -- unused argument 'self'
    "212/...", -- unused variable length argument
}

globals = {
    "PvPBattlegroundFactionIconDB",
    "SLASH_PBFI1",
    "SlashCmdList",
}

read_globals = {
    "C_EditMode",
    "C_Timer",
    "CreateFrame",
    "GetBattlefieldArenaFaction",
    "IsInInstance",
    "LibStub",
    "UIParent",
    "UnitFactionGroup",
}

files["Tests/**/*.lua"] = {
    std = "lua51+busted",
}

files["Tests/PvPBattlegroundFactionIcon_spec.lua"] = {
    ignore = { "512" },
}

files["Tests/TestHelpers.lua"] = {
    ignore = { "432" },
}
