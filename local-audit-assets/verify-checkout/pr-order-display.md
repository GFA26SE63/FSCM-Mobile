Order timestamps were formatted as raw UTC, so the demo order DH-001065 showed 11:57 instead of Vietnam 18:57. Display business timestamps in UTC+7 regardless of the device time zone, preserve UTC markers in cached JSON, and keep expiry/due calendar dates unchanged. Use the shared formatter for the order-screen sync timestamp as well.

When quantity promotions and shelf-life discounts coexist, every line used the common HSD table code as its promotion group, replacing campaign names with a generic label. Preserve the named campaign snapshot and split the summary into each campaign amount plus the shelf-life amount. For DH-001065 this is 512,000 + 455,000 + 274,150 = 1,241,150 discount, leaving the existing 5,208,850 total. Legacy/offline lines and cache round trips retain their discounts.

Full-suite validation on current develop also exposed the existing refresh-token retry test failure: a retried 401 was caught again as a refresh failure, emitting logout twice; a retried 403 was turned into 401. Keep retried-request errors outside the refresh catch and add a 403 regression check.

Validation: flutter analyze clean; all 79 tests passed; debug APK built and installed. Tests cover equivalent timestamp offsets, midnight rollover, date-only expiry/due dates, cache restoration, mixed/pure/legacy discounts, exact demo amounts and long campaign names at 360px. Graphify update was attempted but the CLI is not installed and no graph exists in this checkout.

Native verification on the existing paid demo order DH-001065: the list and detail show Vietnam 18:57 on 08/11, the two campaign names appear separately at 512,000 and 455,000, and the shelf-life row shows 274,150. No new order or payment was created for this fix.
