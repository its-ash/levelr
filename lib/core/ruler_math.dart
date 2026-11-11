// Pure math for the on-screen ruler.
//
// Flutter lays out in logical pixels; the display reports physical dots per
// inch. A logical pixel is `devicePixelRatio` physical pixels.

const double mmPerInch = 25.4;

/// Width of a standard ID-1 bank card (ISO/IEC 7810), in millimetres.
const double bankCardWidthMm = 85.60;

/// Allowed range for the saved correction factor, to reject a bad calibration.
const double minCorrection = 0.5;
const double maxCorrection = 2.0;

/// Use this when the device does not report a usable DPI (Android's baseline).
const double fallbackDpi = 160;

/// A DPI is usable if it is a plausible phone or tablet value.
bool isPlausibleDpi(double? dpi) => dpi != null && dpi.isFinite && dpi >= 80 && dpi <= 1200;

/// Logical pixels in one millimetre on this display.
///
/// [dpi] is the physical DPI along the measured axis, [devicePixelRatio] the
/// Flutter pixel ratio, and [correction] the user's calibration factor.
double logicalPxPerMm({
  required double dpi,
  required double devicePixelRatio,
  double correction = 1,
}) {
  assert(devicePixelRatio > 0);
  final physicalPxPerMm = (isPlausibleDpi(dpi) ? dpi : fallbackDpi) / mmPerInch;
  return physicalPxPerMm / devicePixelRatio * correction;
}

double pxToMm(double px, double pxPerMm) => px / pxPerMm;

double mmToPx(double mm, double pxPerMm) => mm * pxPerMm;

double mmToInches(double mm) => mm / mmPerInch;

double inchesToMm(double inches) => inches * mmPerInch;

/// New correction factor after the user measured a reference object.
///
/// The ruler currently reads [measuredMm] for something that is really
/// [actualMm] long. If it reads too much, the pixels per mm are too small and
/// must grow, so the factor is multiplied by `measured / actual`.
double calibratedCorrection({
  required double currentCorrection,
  required double measuredMm,
  double actualMm = bankCardWidthMm,
}) {
  if (measuredMm <= 0 || actualMm <= 0) return currentCorrection;
  return (currentCorrection * measuredMm / actualMm).clamp(minCorrection, maxCorrection).toDouble();
}

/// Formats a length in millimetres as centimetres, e.g. `8.56 cm`.
String formatCentimetres(double mm) => '${(mm / 10).toStringAsFixed(2)} cm';

/// Formats a length in millimetres as inches, e.g. `3.37 in`.
String formatInches(double mm) => '${mmToInches(mm).toStringAsFixed(2)} in';
