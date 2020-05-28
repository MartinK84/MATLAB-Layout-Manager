addpath('../')
close all;

% create a figure with a simple plot
fig1 = figure(1);
x = linspace(0, 2 * pi, 1000);
y = sin(x);
plot(x,y, 'LineWidth', 2);
xlim([0, 2 * pi]);
img = getframe(fig1);
imwrite(img.cdata, 'Figure001.png');

% make the figure look resonably good
grid on;
grid minor;
axis1 = fig1.CurrentAxes(1);
axis1.XAxis.LineWidth = 2;
axis1.YAxis.LineWidth = 2;
axis1.FontSize = 18;
fig1.Color = 'white';
img = getframe(fig1);
imwrite(img.cdata, 'Figure002.png');

% save the layout of the current figure, including the line properties
LayoutManager.Save('Demo', fig1, 'Line');

% create another figure
fig2 = figure(2);
x = linspace(0, 2 * pi, 1000);
y = sin(x);
y2 = cos(x);
plot(x,y);
hold on;
plot(x,y2);
hold off;
xlim([0, 2 * pi]);
img = getframe(fig2);
imwrite(img.cdata, 'Figure003.png');

% simply apply the previously saved Demo layout
LayoutManager.ApplyLayout('Demo', fig2);
img = getframe(fig2);
imwrite(img.cdata, 'Figure004.png');