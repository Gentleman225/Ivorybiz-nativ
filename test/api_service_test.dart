import 'package:flutter_test/flutter_test.dart';
import 'package:ivorybiz_app/services/api_service.dart';

void main() {
  group('ApiService.isPaymentConfirmed', () {
    test('does not treat API initialization success as payment success', () {
      expect(ApiService.isPaymentConfirmed({'success': true}), isFalse);
      expect(
        ApiService.isPaymentConfirmed({'success': true, 'status': 'pending'}),
        isFalse,
      );
      expect(
        ApiService.isPaymentConfirmed({'success': true, 'status': 'success'}),
        isFalse,
      );
    });

    test('accepts explicit final payment statuses', () {
      expect(ApiService.isPaymentConfirmed({'payment_status': 'paid'}), isTrue);
      expect(ApiService.isPaymentConfirmed({'status': 'completed'}), isTrue);
      expect(
        ApiService.isPaymentConfirmed({'payment_status': 'SUCCESS'}),
        isTrue,
      );
    });

    test('accepts payment-init success payloads from nested backend responses', () {
      expect(
        ApiService.isPaymentInitSuccess({
          'success': true,
          'data': {'payment_url': 'https://example.test/pay'}
        }),
        isTrue,
      );
      expect(
        ApiService.isPaymentInitSuccess({
          'status': 'success',
          'data': {'payment_url': 'https://example.test/pay'}
        }),
        isTrue,
      );
      expect(
        ApiService.isPaymentInitSuccess({
          'success': false,
          'error': 'Payment initialization failed'
        }),
        isFalse,
      );
    });

    test('extracts app links and browser fallbacks from the API response', () {
      final result = {
        'data': {
          'deep_link': 'wave://pay/checkout',
          'fallback_url': 'https://pay.example.com/checkout',
        },
      };
      final appUri = ApiService.paymentUri(result);

      expect(appUri?.scheme, 'wave');
      expect(
        ApiService.paymentFallbackUri(result, primaryUri: appUri!),
        Uri.parse('https://pay.example.com/checkout'),
      );
    });

    test('ignores unsafe and malformed payment links', () {
      expect(ApiService.paymentUri({'payment_url': 'javascript:alert(1)'}),
          isNull);
      expect(ApiService.paymentUri({'payment_url': '/checkout'}), isNull);
    });

    test('only treats paid WooCommerce orders with a payment date as paid', () {
      expect(
        ApiService.isWooOrderPaid({
          'status': 'processing',
          'date_paid': '2026-09-27T12:00:00',
        }),
        isTrue,
      );
      expect(
        ApiService.isWooOrderPaid({'status': 'processing', 'date_paid': null}),
        isFalse,
      );
      expect(
        ApiService.isWooOrderPaid({
          'status': 'pending',
          'date_paid': '2026-09-27T12:00:00',
        }),
        isFalse,
      );
    });
  });
}
