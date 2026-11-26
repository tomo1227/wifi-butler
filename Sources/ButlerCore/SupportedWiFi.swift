public enum SupportedWiFi {
  public static let ssids: Set<String> = [
    "00_MCD-FREE-WIFI",
    "309cafe_Wi-Fi",
    "DOUTOR_FREE_Wi-Fi",
    "FreeWiFi-NARITA",
    "HANEDA-FREE-WIFI",
    "JR-Central_FREE",
    "JR-EAST_FREE_Wi-Fi",
    "Shinkansen_Free_Wi-Fi",
    "at_STARBUCKS_Wi2",
    "tullys_Wi-Fi",
  ]

  public static func matches(_ current: WiFiSnapshot, expected: WiFiSnapshot) -> Bool {
    current == expected
  }
}
