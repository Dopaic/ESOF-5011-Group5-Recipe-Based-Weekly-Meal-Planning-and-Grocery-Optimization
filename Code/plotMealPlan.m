function plotFiles = plotMealPlan(menuTable, shoppingTable, dailyNutritionTable, candidateTable, selectedCandidate, data, outputFolder, timeStamp)
% Result plots

plotFiles = strings(4, 1);

% Calories and protein
figure('Visible', 'off');

orderedDays = categorical(dailyNutritionTable.Day, data.DayNames);

yyaxis left;
bar(orderedDays, dailyNutritionTable.Calories_kcal);
ylabel('Calories (kcal)');
yyaxis right;
plot(orderedDays, dailyNutritionTable.Protein_g, '-o', 'LineWidth', 1.5);
ylabel('Protein (g)');
title('Daily Calories and Protein');
grid on;
plotFiles(1) = fullfile(outputFolder, ['DailyNutrition_' timeStamp '.png']);
exportgraphics(gcf, plotFiles(1), 'Resolution', 180);
close(gcf);

% Cuisine composition
[cuisineNames, ~, groupIndex] = unique(menuTable.Cuisine);
cuisineCounts = accumarray(groupIndex, 1);
figure('Visible', 'off');
pie(cuisineCounts, cellstr(cuisineNames));
title('Cuisine Mix of the Selected Weekly Menu');
plotFiles(2) = fullfile(outputFolder, ['CuisineMix_' timeStamp '.png']);
exportgraphics(gcf, plotFiles(2), 'Resolution', 180);
close(gcf);

% Ingredient costs
[sortedCost, order] = sort(shoppingTable.TotalCost_CAD, 'descend');
numberToShow = min(12, numel(order));

% Top-cost ingredients
topNames = shoppingTable.Ingredient(order(1:numberToShow));
topCosts = sortedCost(1:numberToShow);

topNames = flip(topNames);
topCosts = flip(topCosts);

orderedIngredientNames = categorical(topNames, topNames);

figure('Visible', 'off');
barh(orderedIngredientNames, topCosts);
xlabel('Cost (CAD)');
title('Largest Grocery Cost Items');
grid on;
plotFiles(3) = fullfile(outputFolder, ['ShoppingCost_' timeStamp '.png']);
exportgraphics(gcf, plotFiles(3), 'Resolution', 180);
close(gcf);
% Candidate comparison
figure('Visible', 'off');
scatter(candidateTable.TotalCost_CAD, candidateTable.QualityValue, 70, ...
    candidateTable.AveragePreference, 'filled');
xlabel('Total Cost (CAD)');
ylabel('Quality Value (lower is better)');
title('Near-Optimal Candidate Menu Pool');
colorbar;
grid on;
plotFiles(4) = fullfile(outputFolder, ['CandidatePool_' timeStamp '.png']);
exportgraphics(gcf, plotFiles(4), 'Resolution', 180);
close(gcf);
end
