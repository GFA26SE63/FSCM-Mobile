# Shared Flutter building blocks

This directory owns business concepts and UI that are reusable across FSCM roles.

- `domain/` contains cross-role models such as products, retailers, orders, order lines, statuses, promotions, and notifications.
- `widgets/` contains composed business widgets such as order summaries, inventory labels, quantity controls, progress summaries, and status presentation.
- `rbac/` contains permission-aware UI conventions after the backend permission contract is approved.

Shared widgets must accept data and callbacks instead of reading a role-specific controller. A Sales, Retailer, Warehouse, Operator, or Administrator feature should be able to compose them without importing another role's feature directory.

Keep truly role-specific workflows in `lib/features/<feature>`. Examples include the Sales quantity selector and retailer-potential form, Warehouse label splitting, and Retailer receipt reconciliation.
