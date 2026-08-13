function updateMonthlyPricesInteractive(dataFile)
% Monthly prices

ingredients = readtable(dataFile, 'Sheet', 'Ingredients', 'TextType', 'string');
prices = readtable(dataFile, 'Sheet', 'Prices', 'TextType', 'string');
settingsTable = readtable(dataFile, 'Sheet', 'Settings', 'TextType', 'string');

fprintf('\n--- Add or Update Monthly Prices ---\n');
newMonth = strtrim(input('Month in YYYY-MM format: ', 's'));
if isempty(regexp(newMonth, '^\d{4}-\d{2}$', 'once'))
    error('Month must use the YYYY-MM format.');
end
newMonth = string(newMonth);

% Latest baseline
availableMonths = sort(unique(prices.Month));
if isempty(availableMonths)
    baselineMonth = "";
else
    baselineMonth = availableMonths(end);
end

numberOfIngredients = height(ingredients);
monthPrice = ingredients.DefaultPrice_CAD;

if baselineMonth ~= ""
    for ingredientIndex = 1:numberOfIngredients
        matchingRow = prices.Month == baselineMonth & ...
            prices.IngredientID == ingredients.IngredientID(ingredientIndex);
        if any(matchingRow)
            monthPrice(ingredientIndex) = prices.PricePerPackage_CAD(find(matchingRow, 1));
        end
    end
end

fprintf('Baseline prices copied from %s.\n', char(baselineMonth));
fprintf('Enter an ingredient name to change its price. Leave blank when finished.\n');

while true
    ingredientName = strtrim(input('Ingredient name: ', 's'));
    if isempty(ingredientName)
        break;
    end

    ingredientIndex = find(strcmpi(ingredients.IngredientName, ingredientName), 1);
    if isempty(ingredientIndex)
        fprintf('Ingredient not found. Use option 2 in the main program to add it first.\n');
        continue;
    end

    fprintf('Current copied price for %s: CAD %.2f\n', ...
        ingredients.IngredientName(ingredientIndex), monthPrice(ingredientIndex));
    newPriceText = strtrim(input('New package price (CAD): ', 's'));
    newPrice = str2double(newPriceText);
    if isfinite(newPrice) && newPrice > 0
        monthPrice(ingredientIndex) = newPrice;
    else
        fprintf('Invalid price. The copied price was kept.\n');
    end
end

% Replace month
prices(prices.Month == newMonth, :) = [];
newRows = table( ...
    repmat(newMonth, numberOfIngredients, 1), ...
    ingredients.IngredientID, ...
    monthPrice, ...
    repmat("User monthly scenario", numberOfIngredients, 1), ...
    'VariableNames', prices.Properties.VariableNames);
prices = [prices; newRows];
writetable(prices, dataFile, 'Sheet', 'Prices', 'WriteMode', 'overwritesheet');

% Default month
setDefault = lower(strtrim(input('Use this as the default month? [Y/n]: ', 's')));
if isempty(setDefault) || strcmp(setDefault, 'y') || strcmp(setDefault, 'yes')
    selectedRow = settingsTable.Parameter == "SelectedMonth";
    if any(selectedRow)
        settingsTable.Value(selectedRow) = newMonth;
    else
        newSetting = table("SelectedMonth", newMonth, ...
            "Month used for the price scenario (YYYY-MM)", ...
            'VariableNames', settingsTable.Properties.VariableNames);
        settingsTable = [settingsTable; newSetting];
    end
    writetable(settingsTable, dataFile, 'Sheet', 'Settings', 'WriteMode', 'overwritesheet');
end

fprintf('Monthly prices for %s were saved.\n', char(newMonth));
end
