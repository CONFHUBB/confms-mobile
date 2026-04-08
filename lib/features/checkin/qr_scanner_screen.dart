import 'package:confms_mobile/constants/app_theme.dart';
import 'package:confms_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// QR Scanner screen for Chair/Staff to check-in attendees.
/// Uses `mobile_scanner` to scan QR codes and calls
/// POST /api/v1/check-in?code={code} to process check-in.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _processing = false;
  bool _scanLocked = false;
  _CheckInResult? _lastResult;
  final List<_CheckInResult> _history = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || _scanLocked) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final code = barcode.rawValue!;
    if (code.isEmpty) return;

    setState(() => _processing = true);

    try {
      final data = await widget.apiService.post(
        '/check-in?code=${Uri.encodeComponent(code)}',
      );
      final result = _CheckInResult(
        success: true,
        attendeeName: (data['attendeeName'] ?? '') as String,
        attendeeEmail: (data['attendeeEmail'] ?? '') as String,
        ticketType: (data['ticketTypeName'] ?? '') as String,
        registrationNumber: (data['registrationNumber'] ?? '') as String,
        message: (data['message'] ?? 'Check-in successful') as String,
        isCheckedIn: data['isCheckedIn'] == true,
      );

      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _history.insert(0, result);
      });
      _showResultDialog(result);
      if (result.success) {
        await _controller.stop();
        if (mounted) {
          setState(() => _scanLocked = true);
        }
      }
    } catch (e) {
      if (!mounted) return;
      final result = _CheckInResult(success: false, message: e.toString());
      setState(() {
        _lastResult = result;
        _history.insert(0, result);
      });
      _showResultDialog(result);
    } finally {
      // Wait before allowing next scan
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  void _showResultDialog(_CheckInResult result) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.scheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Status icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: (result.success ? Colors.green : Colors.red).withValues(
                  alpha: 0.12,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                result.success
                    ? Icons.check_circle_rounded
                    : Icons.error_rounded,
                size: 40,
                color: result.success ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              result.success ? 'Check-in Successful!' : 'Check-in Failed',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: result.success ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            if (result.success) ...[
              _ResultRow(
                icon: Icons.person_rounded,
                label: 'Attendee',
                value: result.attendeeName,
              ),
              if (result.attendeeEmail.isNotEmpty)
                _ResultRow(
                  icon: Icons.email_rounded,
                  label: 'Email',
                  value: result.attendeeEmail,
                ),
              _ResultRow(
                icon: Icons.confirmation_num_rounded,
                label: 'Ticket',
                value: result.ticketType,
              ),
              _ResultRow(
                icon: Icons.tag_rounded,
                label: 'Registration #',
                value: result.registrationNumber,
              ),
              if (result.isCheckedIn)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Already checked in',
                          style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                            color: Colors.amber.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ] else
              Text(
                result.message,
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (result.success) {
                    await _controller.start();
                    if (mounted) {
                      setState(() => _scanLocked = false);
                    }
                  }
                },
                child: Text(result.success ? 'Scan Next' : 'Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Check-in'),
        centerTitle: true,
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: Badge(
                label: Text('${_history.length}'),
                child: const Icon(Icons.history_rounded),
              ),
              onPressed: () => _showHistory(context),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Camera
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // Scan overlay
          _ScanOverlay(processing: _processing),

          // Bottom bar with flash + camera toggle
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlButton(
                    icon: Icons.flash_on_rounded,
                    label: 'Flash',
                    onTap: () => _controller.toggleTorch(),
                  ),
                  // Center scan hint
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _processing ? 'Processing...' : 'Point at QR code',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  _ControlButton(
                    icon: Icons.cameraswitch_rounded,
                    label: 'Flip',
                    onTap: () => _controller.switchCamera(),
                  ),
                ],
              ),
            ),
          ),

          // Last result mini banner
          if (_lastResult != null)
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_lastResult!.success ? Colors.green : Colors.red)
                      .withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      _lastResult!.success
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lastResult!.success
                            ? '${_lastResult!.attendeeName} checked in'
                            : 'Failed: ${_lastResult!.message}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.scheme.onSurfaceVariant.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Scan History',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_history.length} scans',
                        style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _history.length,
                itemBuilder: (_, i) {
                  final r = _history[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (r.success ? Colors.green : Colors.red).withValues(
                        alpha: 0.06,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (r.success ? Colors.green : Colors.red)
                            .withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          r.success
                              ? Icons.check_circle_rounded
                              : Icons.error_rounded,
                          color: r.success ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.success ? r.attendeeName : 'Failed',
                                style: Theme.of(ctx).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                r.success
                                    ? '${r.ticketType} • ${r.registrationNumber}'
                                    : r.message,
                                style: Theme.of(ctx).textTheme.bodySmall
                                    ?.copyWith(
                                      color: context.scheme.onSurfaceVariant,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scan overlay with animated corners ──
class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay({required this.processing});
  final bool processing;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 260,
        height: 260,
        child: Stack(
          children: [
            // Background dim outside scan area
            // Top-left corner
            Positioned(left: 0, top: 0, child: _Corner(processing: processing)),
            // Top-right corner
            Positioned(
              right: 0,
              top: 0,
              child: Transform.flip(
                flipX: true,
                child: _Corner(processing: processing),
              ),
            ),
            // Bottom-left corner
            Positioned(
              left: 0,
              bottom: 0,
              child: Transform.flip(
                flipY: true,
                child: _Corner(processing: processing),
              ),
            ),
            // Bottom-right corner
            Positioned(
              right: 0,
              bottom: 0,
              child: Transform.flip(
                flipX: true,
                flipY: true,
                child: _Corner(processing: processing),
              ),
            ),
            // Processing indicator
            if (processing)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.processing});
  final bool processing;

  @override
  Widget build(BuildContext context) {
    final color = processing ? Colors.amber : Colors.white;
    return SizedBox(
      width: 40,
      height: 40,
      child: CustomPaint(painter: _CornerPainter(color: color)),
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => color != old.color;
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInResult {
  const _CheckInResult({
    required this.success,
    this.attendeeName = '',
    this.attendeeEmail = '',
    this.ticketType = '',
    this.registrationNumber = '',
    this.message = '',
    this.isCheckedIn = false,
  });
  final bool success;
  final String attendeeName;
  final String attendeeEmail;
  final String ticketType;
  final String registrationNumber;
  final String message;
  final bool isCheckedIn;
}
