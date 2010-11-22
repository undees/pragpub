public class Analysis {
    public static void main(String[] args) throws java.io.IOException {
        TemperatureTaker tt = new TemperatureTaker();
        tt.start();

        System.out.println("Listening for temperature; press Enter to stop");
        System.in.read();

        tt.stop();

        System.out.println("Temperature is " + tt.temperature());
    }
}
