javaaddpath "/path/to/your/project"

tt = TemperatureTaker();
tt.start();

printf("Listening for temperature for 10 seconds\n");

v = [];
for i = 1:10,
    sleep(1);
    v(i) = tt.temperature();
end
tt.stop();

plot(v);
