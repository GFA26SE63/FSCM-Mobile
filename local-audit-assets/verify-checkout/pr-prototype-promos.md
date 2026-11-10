Preserve CampaignMode and per-SKU threshold/rate rules from the server snapshot instead of coercing every campaign into a product-group promotion. Convert product identifiers to SKU codes for the existing local promotion calculator and retain the rules through cache round trips. The online cart remains server-priced.

Requires the backend prototype promotion API/snapshot changes. Stacked on #43.

Validation: flutter analyze clean; all 41 tests passed, including independent per-SKU thresholds after sync/cache. Android debug APK built and installed on emulator-5554. Real Retailer mobile/snapshot returns KM-006 with both SKU rules and KM-007 as ProductGroup.
