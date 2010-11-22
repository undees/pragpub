javaaddpath('/path/to/your/project');

tt = TemperatureTaker();
tt.start();

fprintf('Listening for temperature for 10 seconds\n');

v = [];
for i = 1:10,
    pause(1);
    v(i) = tt.temperature();
end
tt.stop();

plot(v);
