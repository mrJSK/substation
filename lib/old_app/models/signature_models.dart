class SignatureData {
  final String designation;
  final String name;
  final String department;
  final DateTime signedAt;
  final bool isRequired;

  SignatureData({
    required this.designation,
    required this.name,
    required this.department,
    required this.signedAt,
    this.isRequired = true,
  });
}

class DistributionFeederData {
  final String feederName;
  final String distributionZone;
  final String distributionCircle;
  final String distributionDivision;
  final String distributionSubdivision;
  final double importEnergy;
  final double exportEnergy;
  final double netEnergy;
  final String feederType;

  DistributionFeederData({
    required this.feederName,
    required this.distributionZone,
    required this.distributionCircle,
    required this.distributionDivision,
    required this.distributionSubdivision,
    required this.importEnergy,
    required this.exportEnergy,
    required this.feederType,
  }) : netEnergy = importEnergy - exportEnergy;
}
