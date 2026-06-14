import type { Listing } from "../types";
import { normalize, score } from "../searchEngine";

/** ISO date `n` days before now (UTC, midnight). Keeps sample sold dates evergreen. */
function daysAgo(n: number): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - n);
  d.setUTCHours(0, 0, 0, 0);
  return d.toISOString();
}

export interface SampleDataset {
  keywords: string[];
  sold: Listing[];
  active: Listing[];
}

const USD = "USD";

const datasets: SampleDataset[] = [
  {
    keywords: ["adesanya", "israel adesanya", "ufc", "prizm", "panini prizm ufc", "stylebender"],
    sold: [
      { id: "ufc-s1", title: "2021 Panini Prizm UFC Israel Adesanya #1 PSA 10 Gem Mint", kind: "sold", price: 72.5, currencyCode: USD, soldDate: daysAgo(16), condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "ufc-s2", title: "2021 Panini Prizm UFC Israel Adesanya #1 Base Raw NM", kind: "sold", price: 11.99, currencyCode: USD, soldDate: daysAgo(11), condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 4.99 },
      { id: "ufc-s3", title: "2021 Panini Prizm UFC Israel Adesanya Silver Prizm #1 PSA 9", kind: "sold", price: 58.0, currencyCode: USD, soldDate: daysAgo(29), condition: { gradingCompany: "PSA", grade: 9 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "ufc-s4", title: "2021 Panini Prizm UFC Israel Adesanya #1 Raw Ungraded", kind: "sold", price: 9.5, currencyCode: USD, soldDate: daysAgo(5), condition: { rawDescription: "Lightly Played" }, marketplace: "eBay", shippingPrice: 4.0 },
      { id: "ufc-s5", title: "2021 Panini Prizm UFC Israel Adesanya Silver Prizm Raw NM-MT", kind: "sold", price: 34.0, currencyCode: USD, soldDate: daysAgo(44), condition: { rawDescription: "Near Mint-Mint" }, marketplace: "eBay", shippingPrice: 5.0 },
      { id: "ufc-s6", title: "2021 Panini Prizm UFC Israel Adesanya #1 BGS 9.5 Gem Mint", kind: "sold", price: 95.0, currencyCode: USD, soldDate: daysAgo(70), condition: { gradingCompany: "BGS", grade: 9.5 }, marketplace: "eBay", shippingPrice: 0 },
    ],
    active: [
      { id: "ufc-a1", title: "2021 Panini Prizm UFC Israel Adesanya #1 PSA 10 Gem Mint", kind: "active", price: 89.99, currencyCode: USD, condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "ufc-a2", title: "2021 Panini Prizm UFC Israel Adesanya #1 Base Raw Near Mint", kind: "active", price: 14.99, currencyCode: USD, condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 4.99 },
      { id: "ufc-a3", title: "2021 Panini Prizm UFC Israel Adesanya Silver Prizm #1 Raw", kind: "active", price: 44.0, currencyCode: USD, condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 5.0 },
      { id: "ufc-a4", title: "2021 Panini Prizm UFC Israel Adesanya #1 PSA 9 Mint", kind: "active", price: 65.0, currencyCode: USD, condition: { gradingCompany: "PSA", grade: 9 }, marketplace: "eBay", shippingPrice: 0 },
    ],
  },
  {
    keywords: ["hamilton", "lewis hamilton", "f1", "formula 1", "topps chrome", "rookie", "mercedes"],
    sold: [
      { id: "f1-s1", title: "2020 Topps Chrome Formula 1 Lewis Hamilton #1 RC PSA 10", kind: "sold", price: 340.0, currencyCode: USD, soldDate: daysAgo(22), condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "f1-s2", title: "2020 Topps Chrome Formula 1 Lewis Hamilton #1 Rookie Raw NM", kind: "sold", price: 44.99, currencyCode: USD, soldDate: daysAgo(8), condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 5.0 },
      { id: "f1-s3", title: "2020 Topps Chrome F1 Lewis Hamilton Refractor #1 PSA 10", kind: "sold", price: 520.0, currencyCode: USD, soldDate: daysAgo(56), condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "f1-s4", title: "2020 Topps Chrome Formula 1 Lewis Hamilton #1 RC Raw", kind: "sold", price: 39.0, currencyCode: USD, soldDate: daysAgo(12), condition: { rawDescription: "Lightly Played" }, marketplace: "eBay", shippingPrice: 4.5 },
      { id: "f1-s5", title: "2020 Topps Chrome F1 Lewis Hamilton #1 PSA 9 Mint", kind: "sold", price: 180.0, currencyCode: USD, soldDate: daysAgo(34), condition: { gradingCompany: "PSA", grade: 9 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "f1-s6", title: "2020 Topps Chrome Formula 1 Lewis Hamilton Refractor Raw NM-MT", kind: "sold", price: 120.0, currencyCode: USD, soldDate: daysAgo(77), condition: { rawDescription: "Near Mint-Mint" }, marketplace: "eBay", shippingPrice: 5.0 },
    ],
    active: [
      { id: "f1-a1", title: "2020 Topps Chrome Formula 1 Lewis Hamilton #1 RC PSA 10", kind: "active", price: 399.0, currencyCode: USD, condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "f1-a2", title: "2020 Topps Chrome Formula 1 Lewis Hamilton #1 Rookie Raw NM-MT", kind: "active", price: 54.99, currencyCode: USD, condition: { rawDescription: "Near Mint-Mint" }, marketplace: "eBay", shippingPrice: 4.99 },
      { id: "f1-a3", title: "2020 Topps Chrome F1 Lewis Hamilton Refractor #1 Raw", kind: "active", price: 149.99, currencyCode: USD, condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 6.0 },
      { id: "f1-a4", title: "2020 Topps Chrome Formula 1 Lewis Hamilton #1 BGS 9.5", kind: "active", price: 260.0, currencyCode: USD, condition: { gradingCompany: "BGS", grade: 9.5 }, marketplace: "eBay", shippingPrice: 0 },
    ],
  },
  {
    keywords: ["charizard", "charizard vmax", "pokemon", "champion's path", "champions path", "074/073", "secret rare", "tcg", "trading card game"],
    sold: [
      { id: "pkm-s1", title: "Pokemon Charizard VMAX Champion's Path 074/073 PSA 10", kind: "sold", price: 145.0, currencyCode: USD, soldDate: daysAgo(14), condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "pkm-s2", title: "Pokemon Charizard VMAX Champion's Path 074/073 Secret Rare Raw NM", kind: "sold", price: 52.0, currencyCode: USD, soldDate: daysAgo(7), condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 4.99 },
      { id: "pkm-s3", title: "Charizard VMAX 074/073 Champion's Path PSA 9 Mint", kind: "sold", price: 78.0, currencyCode: USD, soldDate: daysAgo(32), condition: { gradingCompany: "PSA", grade: 9 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "pkm-s4", title: "Pokemon Charizard VMAX Champion's Path 074/073 Raw Ungraded", kind: "sold", price: 44.99, currencyCode: USD, soldDate: daysAgo(4), condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 3.99 },
      { id: "pkm-s5", title: "Charizard VMAX Champion's Path 074/073 CGC 9.5 Gem Mint", kind: "sold", price: 96.0, currencyCode: USD, soldDate: daysAgo(49), condition: { gradingCompany: "CGC", grade: 9.5 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "pkm-s6", title: "Pokemon Charizard VMAX Champion's Path Secret Rare Raw LP", kind: "sold", price: 38.0, currencyCode: USD, soldDate: daysAgo(90), condition: { rawDescription: "Lightly Played" }, marketplace: "eBay", shippingPrice: 4.0 },
    ],
    active: [
      { id: "pkm-a1", title: "Pokemon Charizard VMAX Champion's Path 074/073 PSA 10", kind: "active", price: 169.99, currencyCode: USD, condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "pkm-a2", title: "Charizard VMAX 074/073 Champion's Path Secret Rare Raw NM", kind: "active", price: 59.99, currencyCode: USD, condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 4.99 },
      { id: "pkm-a3", title: "Pokemon Charizard VMAX Champion's Path 074/073 Raw Pack Fresh", kind: "active", price: 49.99, currencyCode: USD, condition: { rawDescription: "Near Mint-Mint" }, marketplace: "eBay", shippingPrice: 3.99 },
      { id: "pkm-a4", title: "Charizard VMAX Champion's Path 074/073 PSA 9 Mint", kind: "active", price: 89.0, currencyCode: USD, condition: { gradingCompany: "PSA", grade: 9 }, marketplace: "eBay", shippingPrice: 0 },
    ],
  },
  {
    keywords: ["luka", "doncic", "luka doncic", "prizm", "panini prizm", "2018 prizm", "mavericks", "nba"],
    sold: [
      { id: "nba-s1", title: "2018-19 Panini Prizm Luka Doncic #280 RC PSA 10", kind: "sold", price: 305.0, currencyCode: USD, soldDate: daysAgo(18), condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "nba-s2", title: "2018-19 Panini Prizm Luka Doncic #280 Rookie Raw NM", kind: "sold", price: 44.0, currencyCode: USD, soldDate: daysAgo(6), condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 4.99 },
      { id: "nba-s3", title: "2018-19 Panini Prizm Luka Doncic #280 PSA 9 Mint", kind: "sold", price: 118.0, currencyCode: USD, soldDate: daysAgo(27), condition: { gradingCompany: "PSA", grade: 9 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "nba-s4", title: "2018-19 Panini Prizm Luka Doncic #280 RC Raw Ungraded", kind: "sold", price: 36.0, currencyCode: USD, soldDate: daysAgo(3), condition: { rawDescription: "Lightly Played" }, marketplace: "eBay", shippingPrice: 4.0 },
      { id: "nba-s5", title: "2018-19 Panini Prizm Silver Luka Doncic #280 Raw NM-MT", kind: "sold", price: 210.0, currencyCode: USD, soldDate: daysAgo(40), condition: { rawDescription: "Near Mint-Mint" }, marketplace: "eBay", shippingPrice: 5.0 },
      { id: "nba-s6", title: "2018-19 Panini Prizm Luka Doncic #280 BGS 9.5 Gem Mint", kind: "sold", price: 265.0, currencyCode: USD, soldDate: daysAgo(61), condition: { gradingCompany: "BGS", grade: 9.5 }, marketplace: "eBay", shippingPrice: 0 },
    ],
    active: [
      { id: "nba-a1", title: "2018-19 Panini Prizm Luka Doncic #280 RC PSA 10", kind: "active", price: 349.0, currencyCode: USD, condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "nba-a2", title: "2018-19 Panini Prizm Luka Doncic #280 Rookie Raw NM", kind: "active", price: 54.99, currencyCode: USD, condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 4.99 },
      { id: "nba-a3", title: "2018-19 Panini Prizm Silver Luka Doncic #280 Raw", kind: "active", price: 239.99, currencyCode: USD, condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 5.0 },
      { id: "nba-a4", title: "2018-19 Panini Prizm Luka Doncic #280 PSA 9 Mint", kind: "active", price: 139.0, currencyCode: USD, condition: { gradingCompany: "PSA", grade: 9 }, marketplace: "eBay", shippingPrice: 0 },
    ],
  },
  {
    keywords: ["trout", "mike trout", "topps update", "2011 topps update", "angels", "baseball", "us175"],
    sold: [
      { id: "mlb-s1", title: "2011 Topps Update Mike Trout #US175 RC PSA 10", kind: "sold", price: 1250.0, currencyCode: USD, soldDate: daysAgo(20), condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "mlb-s2", title: "2011 Topps Update Mike Trout #US175 Rookie Raw NM", kind: "sold", price: 135.0, currencyCode: USD, soldDate: daysAgo(9), condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 5.0 },
      { id: "mlb-s3", title: "2011 Topps Update Mike Trout #US175 PSA 9 Mint", kind: "sold", price: 305.0, currencyCode: USD, soldDate: daysAgo(31), condition: { gradingCompany: "PSA", grade: 9 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "mlb-s4", title: "2011 Topps Update Mike Trout #US175 RC Raw Ungraded", kind: "sold", price: 99.0, currencyCode: USD, soldDate: daysAgo(5), condition: { rawDescription: "Lightly Played" }, marketplace: "eBay", shippingPrice: 4.5 },
      { id: "mlb-s5", title: "2011 Topps Update Mike Trout #US175 BGS 9.5 Gem Mint", kind: "sold", price: 520.0, currencyCode: USD, soldDate: daysAgo(52), condition: { gradingCompany: "BGS", grade: 9.5 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "mlb-s6", title: "2011 Topps Update Mike Trout #US175 SGC 9", kind: "sold", price: 360.0, currencyCode: USD, soldDate: daysAgo(72), condition: { gradingCompany: "SGC", grade: 9 }, marketplace: "eBay", shippingPrice: 0 },
    ],
    active: [
      { id: "mlb-a1", title: "2011 Topps Update Mike Trout #US175 RC PSA 10", kind: "active", price: 1399.0, currencyCode: USD, condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "mlb-a2", title: "2011 Topps Update Mike Trout #US175 Rookie Raw NM-MT", kind: "active", price: 159.99, currencyCode: USD, condition: { rawDescription: "Near Mint-Mint" }, marketplace: "eBay", shippingPrice: 4.99 },
      { id: "mlb-a3", title: "2011 Topps Update Mike Trout #US175 PSA 9 Mint", kind: "active", price: 349.0, currencyCode: USD, condition: { gradingCompany: "PSA", grade: 9 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "mlb-a4", title: "2011 Topps Update Mike Trout #US175 RC Raw", kind: "active", price: 119.99, currencyCode: USD, condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 5.0 },
    ],
  },
  {
    keywords: ["mbappe", "kylian mbappe", "prizm world cup", "2018 world cup", "soccer", "football", "psg"],
    sold: [
      { id: "soc-s1", title: "2018 Panini Prizm World Cup Kylian Mbappe #80 RC PSA 10", kind: "sold", price: 260.0, currencyCode: USD, soldDate: daysAgo(16), condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "soc-s2", title: "2018 Panini Prizm World Cup Kylian Mbappe #80 Rookie Raw NM", kind: "sold", price: 30.0, currencyCode: USD, soldDate: daysAgo(7), condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 4.99 },
      { id: "soc-s3", title: "2018 Panini Prizm World Cup Kylian Mbappe #80 PSA 9 Mint", kind: "sold", price: 95.0, currencyCode: USD, soldDate: daysAgo(28), condition: { gradingCompany: "PSA", grade: 9 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "soc-s4", title: "2018 Panini Prizm World Cup Kylian Mbappe #80 Raw Ungraded", kind: "sold", price: 24.0, currencyCode: USD, soldDate: daysAgo(4), condition: { rawDescription: "Lightly Played" }, marketplace: "eBay", shippingPrice: 4.0 },
      { id: "soc-s5", title: "2018 Panini Prizm World Cup Silver Mbappe #80 Raw NM-MT", kind: "sold", price: 150.0, currencyCode: USD, soldDate: daysAgo(41), condition: { rawDescription: "Near Mint-Mint" }, marketplace: "eBay", shippingPrice: 5.0 },
      { id: "soc-s6", title: "2018 Panini Prizm World Cup Kylian Mbappe #80 BGS 9.5 Gem Mint", kind: "sold", price: 210.0, currencyCode: USD, soldDate: daysAgo(66), condition: { gradingCompany: "BGS", grade: 9.5 }, marketplace: "eBay", shippingPrice: 0 },
    ],
    active: [
      { id: "soc-a1", title: "2018 Panini Prizm World Cup Kylian Mbappe #80 RC PSA 10", kind: "active", price: 299.0, currencyCode: USD, condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "soc-a2", title: "2018 Panini Prizm World Cup Kylian Mbappe #80 Rookie Raw NM", kind: "active", price: 39.99, currencyCode: USD, condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 4.99 },
      { id: "soc-a3", title: "2018 Panini Prizm World Cup Silver Mbappe #80 Raw", kind: "active", price: 179.99, currencyCode: USD, condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 5.0 },
      { id: "soc-a4", title: "2018 Panini Prizm World Cup Kylian Mbappe #80 PSA 9 Mint", kind: "active", price: 109.0, currencyCode: USD, condition: { gradingCompany: "PSA", grade: 9 }, marketplace: "eBay", shippingPrice: 0 },
    ],
  },
  {
    keywords: ["max verstappen", "verstappen", "f1", "formula 1", "topps chrome", "red bull", "rookie"],
    sold: [
      { id: "vsp-s1", title: "2020 Topps Chrome Formula 1 Max Verstappen #19 RC PSA 10", kind: "sold", price: 225.0, currencyCode: USD, soldDate: daysAgo(19), condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "vsp-s2", title: "2020 Topps Chrome Formula 1 Max Verstappen #19 Rookie Raw NM", kind: "sold", price: 42.0, currencyCode: USD, soldDate: daysAgo(8), condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 5.0 },
      { id: "vsp-s3", title: "2020 Topps Chrome Formula 1 Max Verstappen Autograph Auto /199 BGS 9", kind: "sold", price: 650.0, currencyCode: USD, soldDate: daysAgo(54), condition: { gradingCompany: "BGS", grade: 9 }, marketplace: "eBay", shippingPrice: 0 },
    ],
    active: [
      { id: "vsp-a1", title: "2020 Topps Chrome Formula 1 Max Verstappen #19 RC PSA 10", kind: "active", price: 269.0, currencyCode: USD, condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "vsp-a2", title: "2020 Topps Chrome Formula 1 Max Verstappen Autograph Auto Raw", kind: "active", price: 719.0, currencyCode: USD, condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 0 },
    ],
  },
  {
    keywords: ["victor wembanyama", "wembanyama", "wemby", "nba", "prizm", "panini prizm", "spurs", "rookie"],
    sold: [
      { id: "wemby-s1", title: "2023-24 Panini Prizm Victor Wembanyama #136 RC PSA 10", kind: "sold", price: 305.0, currencyCode: USD, soldDate: daysAgo(22), condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "wemby-s2", title: "2023-24 Panini Prizm Victor Wembanyama #136 Rookie Raw NM", kind: "sold", price: 58.0, currencyCode: USD, soldDate: daysAgo(3), condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 5.0 },
      { id: "wemby-s3", title: "2023-24 Panini Prizm Silver Victor Wembanyama #136 Raw NM-MT", kind: "sold", price: 185.0, currencyCode: USD, soldDate: daysAgo(40), condition: { rawDescription: "Near Mint-Mint" }, marketplace: "eBay", shippingPrice: 5.0 },
    ],
    active: [
      { id: "wemby-a1", title: "2023-24 Panini Prizm Victor Wembanyama #136 RC PSA 10", kind: "active", price: 349.0, currencyCode: USD, condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "wemby-a2", title: "2023-24 Panini Prizm Victor Wembanyama #136 Rookie Raw NM", kind: "active", price: 69.99, currencyCode: USD, condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 4.99 },
    ],
  },
  {
    keywords: ["lionel messi", "messi", "soccer", "football", "prizm world cup", "argentina", "2022 world cup"],
    sold: [
      { id: "messi-s1", title: "2022 Panini Prizm World Cup Lionel Messi #168 PSA 10", kind: "sold", price: 150.0, currencyCode: USD, soldDate: daysAgo(26), condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "messi-s2", title: "2022 Panini Prizm World Cup Lionel Messi #168 Raw NM", kind: "sold", price: 25.0, currencyCode: USD, soldDate: daysAgo(7), condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 4.99 },
      { id: "messi-s3", title: "2022 Panini Prizm World Cup Silver Messi #168 Raw NM-MT", kind: "sold", price: 90.0, currencyCode: USD, soldDate: daysAgo(46), condition: { rawDescription: "Near Mint-Mint" }, marketplace: "eBay", shippingPrice: 5.0 },
    ],
    active: [
      { id: "messi-a1", title: "2022 Panini Prizm World Cup Lionel Messi #168 PSA 10", kind: "active", price: 179.0, currencyCode: USD, condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "messi-a2", title: "2022 Panini Prizm World Cup Lionel Messi #168 Raw NM", kind: "active", price: 32.0, currencyCode: USD, condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 4.99 },
    ],
  },
  {
    keywords: ["conor mcgregor", "mcgregor", "ufc", "prizm", "panini prizm ufc", "notorious"],
    sold: [
      { id: "mcg-s1", title: "2021 Panini Prizm UFC Conor McGregor #1 PSA 10", kind: "sold", price: 120.0, currencyCode: USD, soldDate: daysAgo(24), condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "mcg-s2", title: "2021 Panini Prizm UFC Conor McGregor #1 Base Raw NM", kind: "sold", price: 22.0, currencyCode: USD, soldDate: daysAgo(9), condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 4.99 },
      { id: "mcg-s3", title: "2021 Panini Prizm UFC Conor McGregor Autograph Auto SP", kind: "sold", price: 900.0, currencyCode: USD, soldDate: daysAgo(59), condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 0 },
    ],
    active: [
      { id: "mcg-a1", title: "2021 Panini Prizm UFC Conor McGregor #1 PSA 10", kind: "active", price: 149.0, currencyCode: USD, condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "mcg-a2", title: "2021 Panini Prizm UFC Conor McGregor #1 Raw Near Mint", kind: "active", price: 28.0, currencyCode: USD, condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 4.99 },
    ],
  },
  {
    keywords: ["shohei ohtani", "ohtani", "mlb", "baseball", "topps update", "dodgers", "angels", "rookie"],
    sold: [
      { id: "oht-s1", title: "2018 Topps Update Shohei Ohtani #US1 RC PSA 10", kind: "sold", price: 180.0, currencyCode: USD, soldDate: daysAgo(23), condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "oht-s2", title: "2018 Topps Update Shohei Ohtani #US1 Rookie Raw NM", kind: "sold", price: 35.0, currencyCode: USD, soldDate: daysAgo(11), condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 5.0 },
      { id: "oht-s3", title: "2018 Topps Update Shohei Ohtani #US1 BGS 9.5 Gem Mint", kind: "sold", price: 240.0, currencyCode: USD, soldDate: daysAgo(48), condition: { gradingCompany: "BGS", grade: 9.5 }, marketplace: "eBay", shippingPrice: 0 },
    ],
    active: [
      { id: "oht-a1", title: "2018 Topps Update Shohei Ohtani #US1 RC PSA 10", kind: "active", price: 219.0, currencyCode: USD, condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "oht-a2", title: "2018 Topps Update Shohei Ohtani #US1 Rookie Raw NM-MT", kind: "active", price: 45.0, currencyCode: USD, condition: { rawDescription: "Near Mint-Mint" }, marketplace: "eBay", shippingPrice: 4.99 },
    ],
  },
  {
    keywords: ["umbreon vmax", "umbreon", "pokemon", "evolving skies", "alt art", "moonbreon", "tcg", "215/203"],
    sold: [
      { id: "umb-s1", title: "Pokemon Umbreon VMAX Alt Art Evolving Skies 215/203 PSA 10", kind: "sold", price: 450.0, currencyCode: USD, soldDate: daysAgo(25), condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "umb-s2", title: "Pokemon Umbreon VMAX Alt Art Evolving Skies 215/203 Raw NM", kind: "sold", price: 120.0, currencyCode: USD, soldDate: daysAgo(8), condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 4.99 },
      { id: "umb-s3", title: "Pokemon Umbreon VMAX Alt Art 215/203 PSA 9 Mint", kind: "sold", price: 220.0, currencyCode: USD, soldDate: daysAgo(42), condition: { gradingCompany: "PSA", grade: 9 }, marketplace: "eBay", shippingPrice: 0 },
    ],
    active: [
      { id: "umb-a1", title: "Pokemon Umbreon VMAX Alt Art Evolving Skies 215/203 PSA 10", kind: "active", price: 499.0, currencyCode: USD, condition: { gradingCompany: "PSA", grade: 10 }, marketplace: "eBay", shippingPrice: 0 },
      { id: "umb-a2", title: "Pokemon Umbreon VMAX Alt Art Evolving Skies 215/203 Raw NM", kind: "active", price: 140.0, currencyCode: USD, condition: { rawDescription: "Near Mint" }, marketplace: "eBay", shippingPrice: 4.99 },
    ],
  },
];

/**
 * Engine-based matcher (mirrors the app's SampleCardIndex): scores every card's keywords
 * and titles with the shared SearchEngine and returns the best, or null if nothing clears
 * the floor → a clean no-results state instead of a forced bad match.
 */
export function matchDataset(query: string): SampleDataset | null {
  const nq = normalize(query);
  if (nq.tokens.length === 0) return null;

  let best: { dataset: SampleDataset; score: number } | null = null;
  for (const dataset of datasets) {
    const haystack = [
      ...dataset.keywords,
      ...dataset.sold.map((s) => s.title),
      ...dataset.active.map((a) => a.title),
    ];
    const s = haystack.reduce((max, h) => Math.max(max, score(h, nq)), 0);
    if (!best || s > best.score) best = { dataset, score: s };
  }
  return best && best.score >= 2.0 ? best.dataset : null;
}
