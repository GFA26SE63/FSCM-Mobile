enum RetailerLeadStatus { pending, approved, rejected }

class RetailerLead {
  const RetailerLead({
    required this.id,
    required this.name,
    required this.address,
    required this.contact,
    required this.phone,
    required this.status,
    required this.potentialClass,
    this.retailerCode,
    this.reason,
  });

  final String id;
  final String name;
  final String address;
  final String contact;
  final String phone;
  final RetailerLeadStatus status;
  final String potentialClass;
  final String? retailerCode;
  final String? reason;
}
