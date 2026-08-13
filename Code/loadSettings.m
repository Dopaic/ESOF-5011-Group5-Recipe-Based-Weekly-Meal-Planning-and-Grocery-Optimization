function config = loadSettings(dataFile)
% Model defaults

settingsTable = readtable(dataFile, 'Sheet', 'Settings', 'TextType', 'string');

% Fallback settings
config.SelectedMonth = "2026-05";
config.WeeklyBudget_CAD = 165;
config.ChineseLunchDinnerMin = 8;
config.ChineseLunchDinnerMax = 9;
config.CandidateMenus = 10;
config.NearOptimalTolerance = 0.06;
config.MinimumMealChanges = 4;
config.RandomSeed = 0;
config.WeekdayPrepLimit_min = 105;
config.WeekendPrepLimit_min = 135;
config.CaloriesMin = 1400;
config.CaloriesMax = 2300;
config.ProteinMin_g = 50;
config.CarbsMin_g = 120;
config.CarbsMax_g = 350;
config.FatMin_g = 35;
config.FatMax_g = 95;
config.SugarMax_g = 90;
config.FiberMin_g = 14;
config.SodiumMax_mg = 3300;
config.MaxSameProteinLunchDinner = 5;
config.SolverMaxTime_sec = 90;
config.OutputFolder = "results";
config.PreferenceNoiseWeight = 0.08;

for rowIndex = 1:height(settingsTable)
    parameterName = strtrim(settingsTable.Parameter(rowIndex));
    parameterValue = strtrim(settingsTable.Value(rowIndex));

    switch parameterName
        case "SelectedMonth"
            config.SelectedMonth = parameterValue;
        case "WeeklyBudget_CAD"
            config.WeeklyBudget_CAD = str2double(parameterValue);
        case "ChineseLunchDinnerMin"
            config.ChineseLunchDinnerMin = str2double(parameterValue);
        case "ChineseLunchDinnerMax"
            config.ChineseLunchDinnerMax = str2double(parameterValue);
        case "CandidateMenus"
            config.CandidateMenus = str2double(parameterValue);
        case "NearOptimalTolerance"
            config.NearOptimalTolerance = str2double(parameterValue);
        case "MinimumMealChanges"
            config.MinimumMealChanges = str2double(parameterValue);
        case "RandomSeed"
            config.RandomSeed = str2double(parameterValue);
        case "WeekdayPrepLimit_min"
            config.WeekdayPrepLimit_min = str2double(parameterValue);
        case "WeekendPrepLimit_min"
            config.WeekendPrepLimit_min = str2double(parameterValue);
        case "CaloriesMin"
            config.CaloriesMin = str2double(parameterValue);
        case "CaloriesMax"
            config.CaloriesMax = str2double(parameterValue);
        case "ProteinMin_g"
            config.ProteinMin_g = str2double(parameterValue);
        case "CarbsMin_g"
            config.CarbsMin_g = str2double(parameterValue);
        case "CarbsMax_g"
            config.CarbsMax_g = str2double(parameterValue);
        case "FatMin_g"
            config.FatMin_g = str2double(parameterValue);
        case "FatMax_g"
            config.FatMax_g = str2double(parameterValue);
        case "SugarMax_g"
            config.SugarMax_g = str2double(parameterValue);
        case "FiberMin_g"
            config.FiberMin_g = str2double(parameterValue);
        case "SodiumMax_mg"
            config.SodiumMax_mg = str2double(parameterValue);
        case "MaxSameProteinLunchDinner"
            config.MaxSameProteinLunchDinner = str2double(parameterValue);
        case "SolverMaxTime_sec"
            config.SolverMaxTime_sec = str2double(parameterValue);
        case "OutputFolder"
            config.OutputFolder = parameterValue;
        case "PreferenceNoiseWeight"
            config.PreferenceNoiseWeight = str2double(parameterValue);
    end
end
end
