#!/usr/bin/env python3
"""Source of all UI strings (Hebrew + English). Run to regenerate translations/strings.csv."""
import csv, os

S = {
# General
"GAME_TITLE": ("רמון 40", "Ramon 40"),
"PLAYER_DEFAULT_NAME": ("רוכב", "Rider"),
"BACK": ("חזרה", "Back"),
"LAPS_N": ("%d הקפות", "%d laps"),
"LAP_1": ("הקפה אחת", "1 lap"),
# HUD
"HUD_KMH": ("קמ״ש", "km/h"),
"HUD_POSITION": ("מקום", "Position"),
"HUD_LAP": ("הקפה", "Lap"),
"HUD_BEST": ("שיא", "Best"),
"HUD_WRONG_WAY": ("כיוון שגוי", "Wrong way"),
"HUD_GO": ("סע!", "Go!"),
"HUD_FINISH": ("סיום!", "Finish!"),
"HUD_FINAL_LAP": ("הקפה אחרונה", "Final lap"),
"HUD_LAP_RECORD": ("שיא הקפה חדש!", "New lap record!"),
"HUD_NEW_GHOST": ("רוח רפאים חדשה נשמרה", "New ghost saved"),
# Pause
"PAUSE_TITLE": ("הפסקה", "Paused"),
"PAUSE_RESUME": ("המשך", "Resume"),
"PAUSE_RESTART": ("התחל מחדש", "Restart"),
"PAUSE_QUIT": ("לתפריט הראשי", "Main menu"),
# Results
"RESULTS_TITLE": ("תוצאות", "Results"),
"RESULTS_RIDER": ("רוכב", "Rider"),
"RESULTS_BIKE": ("אופנוע", "Bike"),
"RESULTS_TIME": ("זמן", "Time"),
"RESULTS_BEST": ("הקפה מהירה", "Best lap"),
"RESULTS_DNF": ("לא סיים", "DNF"),
"RESULTS_CONTINUE": ("המשך", "Continue"),
"RESULTS_REPLAY": ("צפה בשידור חוזר", "Watch replay"),
"RESULTS_STANDINGS": ("טבלת האליפות", "Championship standings"),
"RESULTS_TRACK_RECORD": ("שיא המסלול:", "Track record:"),
"RESULTS_WIN": ("ניצחון!", "Victory!"),
"RESULTS_PODIUM": ("על הפודיום!", "Podium!"),
"RESULTS_FINISHED": ("סיימת את המרוץ", "Race complete"),
"REPLAY": ("שידור חוזר", "Replay"),
"REPLAY_HINT": ("חיצים: החלף רוכב ומהירות  ·  אישור: דלג", "Arrows: switch rider and speed  ·  Confirm: skip"),
# Difficulty
"DIFF_EASY": ("קל", "Easy"),
"DIFF_MEDIUM": ("בינוני", "Medium"),
"DIFF_HARD": ("קשה", "Hard"),
# Tracks
"TRACK_RAMON": ("מכתש רמון", "Ramon Crater"),
"TRACK_RAMON_SUB": ("שקיעה על שפת המכתש, ירידת הסרפנטינות ורצפת המכתש", "Sunset on the crater rim, the switchback descent and the crater floor"),
"TRACK_DEADSEA": ("ים המלח", "Dead Sea"),
"TRACK_DEADSEA_SUB": ("צהריים לוהטים בין מצוקי מדבר יהודה למים הטורקיז", "Blazing midday between the Judean cliffs and turquoise water"),
"TRACK_JERUSALEM": ("עליה לירושלים", "Jerusalem Ascent"),
"TRACK_JERUSALEM_SUB": ("לילה בהרי יהודה: יערות, מנהרות ואורות העיר", "Night in the Judean hills: forests, tunnels and city lights"),
"ROUTE_40": ("כביש 40", "Route 40"),
"ROUTE_90": ("כביש 90", "Route 90"),
"ROUTE_1": ("כביש 1", "Route 1"),
# Bikes
"BIKE_SPORT": ("ספורט", "Sport"),
"BIKE_SPORT_DESC": ("ארבעה צילינדרים, פיירינג מלא ומהירות מרבית שאין לה מתחרים. דורש יד עדינה בפניות.", "Inline four, full fairing and unmatched top speed. Needs a gentle hand in corners."),
"BIKE_NAKED": ("נייקד", "Naked"),
"BIKE_NAKED_DESC": ("מנוע שלושה צילינדרים עם מומנט אדיר. תאוצה פראית ואיזון מצוין.", "Torquey triple with brutal acceleration and great balance."),
"BIKE_SUPERMOTO": ("סופרמוטו", "Supermoto"),
"BIKE_SUPERMOTO_DESC": ("חד צילינדר קל וזריז. המלך של הסרפנטינות ושל השוליים המאובקים.", "Light, agile single. King of switchbacks and dusty shoulders."),
"BIKE_CAFE": ("קפה רייסר", "Cafe Racer"),
"BIKE_CAFE_DESC": ("טווין קלאסי עם כרום ונשמה. מהיר בישורות, דורש תכנון בבלימות.", "Classic twin with chrome and soul. Quick on straights, plan your braking."),
# Paints
"PAINT_CRATER_RED": ("אדום מכתש", "Crater red"),
"PAINT_SALT_WHITE": ("לבן מלח", "Salt white"),
"PAINT_NIGHT_BLACK": ("שחור לילה", "Night black"),
"PAINT_SEA_TEAL": ("טורקיז ים", "Sea teal"),
"PAINT_DESERT_SAND": ("חול מדבר", "Desert sand"),
"PAINT_ROAD_BLUE": ("כחול כביש", "Road blue"),
"PAINT_SUNSET_ORANGE": ("כתום שקיעה", "Sunset orange"),
"PAINT_ACACIA_GREEN": ("ירוק שיטה", "Acacia green"),
"PAINT_ROCK_PURPLE": ("סגול סלע", "Rock purple"),
"PAINT_SIGN_GREEN": ("ירוק שלט", "Sign green"),
"PAINT_LINE_YELLOW": ("צהוב קו", "Line yellow"),
"PAINT_CHAMPION_GOLD": ("זהב אלופים", "Champion gold"),
# Tips
"TIP_1": ("החזק את כפתור ההשתופפות בישורות כדי לחתוך את האוויר ולהגיע למהירות גבוהה יותר.", "Hold tuck on straights to cut through the air and gain top speed."),
"TIP_2": ("בלימה חזקה בזמן הטיה אוכלת את האחיזה. בלום לפני הפנייה ושחרר בהדרגה.", "Hard braking while leaned eats grip. Brake before the corner and release gradually."),
"TIP_3": ("הבלם האחורי על עפר מסובב את האופנוע להחלקה מבוקרת.", "The rear brake on dirt swings the bike into a controlled slide."),
"TIP_4": ("הסופרמוטו מרגיש בבית בשוליים. אופנוע הספורט שונא אותם.", "The supermoto feels at home on the shoulders. The sport bike hates them."),
"TIP_5": ("החלף מצלמה בכל רגע: מרדף, מרדף קרוב או מבט מהקסדה.", "Switch cameras any time: chase, close chase or helmet view."),
"TIP_6": ("במצב מרוץ נגד השעון רוח הרפאים של ההקפה הטובה שלך רוכבת לצידך.", "In Time Trial the ghost of your best lap rides alongside you."),
"TIP_7": ("נפלת? האופנוע יחזור לכביש תוך שניות. אפשר גם ללחוץ על חזרה למסלול.", "Crashed? You will be back on the road in seconds. You can also press respawn."),
"TIP_8": ("סיים אליפות כדי לפתוח אופנועים וצבעים חדשים במוסך.", "Finish a championship to unlock new bikes and colors in the garage."),
# Menu
"MENU_SETTINGS": ("הגדרות", "Settings"),
}

def write():
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, "..", "translations", "strings.csv")
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, quoting=csv.QUOTE_MINIMAL, lineterminator="\n")
        w.writerow(["keys", "he", "en"])
        for k, (he, en) in S.items():
            w.writerow([k, he, en])
    print(f"wrote {len(S)} strings")

if __name__ == "__main__":
    write()
