// Basis-URL des Funnels. In der Entwicklung zeigt sie auf die lokale
// Convertive-Instanz, im Build (npm run build, also auch bin/deploy.sh) auf
// Produktion - damit nie versehentlich ein localhost-Link deployt wird.
//
// ELEVENTY_RUN_MODE ist "build" | "watch" | "serve"; nur "build" gilt als
// Produktion. Ueberschreibbar per FUNNEL_BASE=... npm run build.
const IS_BUILD = process.env.ELEVENTY_RUN_MODE === "build";

const FUNNEL_BASE_PROD = "https://gastroekg.convertive.app/funnel/gastro-einkaufsgemeinschaft-55ku31";
const FUNNEL_BASE_DEV = "http://gastroekg.convertive.localhost/funnel/gastro-einkaufsgemeinschaft-55ku31";

// Empfehlungs-Parameter und Pruefregel der Kundennummer.
// Aendert sich das Format, reicht eine Anpassung hier - index.njk liest
// ausschliesslich diese Werte.
const REFERRAL = {
  // Als String, nicht als RegExp-Literal: der Block wird als JSON in die Seite
  // gerendert und dort per new RegExp(...) wieder aufgebaut.
  // ^\d{4,6}$ = 4 bis 6 Ziffern, fuehrende Null erlaubt (0123 ist gueltig).
  pattern: "^\\d{4,6}$",
  errorMessage: "Bitte geben Sie Ihre Kundennummer ein – 4 bis 6 Ziffern.",

  // Akzeptierte Parameter beim Aufruf der Seite. Reihenfolge = Vorrang:
  // kommen beide, gewinnt der erste.
  inParams: ["r", "referrer"],

  // Parameter, mit dem der erzeugte Funnel-Link arbeitet.
  outParam: "r",
};

module.exports = {
  funnelBase: process.env.FUNNEL_BASE || (IS_BUILD ? FUNNEL_BASE_PROD : FUNNEL_BASE_DEV),
  // Ueberschriften fuer den Hero. Beim Aufruf wird per Zufall eine davon
  // angezeigt; ohne JavaScript bleibt die erste stehen. Reihenfolge egal,
  // Anzahl beliebig - eine einzelne Zeile schaltet den Zufall einfach ab.
  headlines: [
    "Sie kennen jemanden, der zu viel bezahlt? Das ist uns bis zu 500 € wert.",
    "Gute Konditionen behält man nicht für sich.",
    "Ihr bester Tipp unter Kollegen – von uns mit bis zu 500 € belohnt.",
  ],

  referral: REFERRAL,
};
