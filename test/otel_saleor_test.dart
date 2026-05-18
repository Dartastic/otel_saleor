// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_saleor/otel_saleor.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_saleor-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('checkoutComplete records channel + payment status', () async {
    await tracedSaleor<String>(
      operationName: 'CheckoutComplete',
      operationType: 'mutation',
      channelSlug: 'default-channel',
      invoke: () async => const SaleorCallResult(
        value: 'ok',
        result: SaleorResult(
          channelSlug: 'default-channel',
          orderStatus: 'UNFULFILLED',
          paymentChargeStatus: 'FULLY_CHARGED',
          checkoutStatus: 'complete',
          totalAmountMinor: 15000,
          currency: 'USD',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('saleor CheckoutComplete')!);
    expect(a['saleor.channel.slug'], 'default-channel');
    expect(a['saleor.payment.charge_status'], 'FULLY_CHARGED');
    expect(a['saleor.checkout.status'], 'complete');
    expect(a['graphql.operation.type'], 'mutation');
  });

  test('INSUFFICIENT_STOCK error code sets span error', () async {
    await tracedSaleor<String>(
      operationName: 'CheckoutLinesAdd',
      invoke: () async => const SaleorCallResult(
        value: 'ok',
        result: SaleorResult(errorCode: 'INSUFFICIENT_STOCK'),
      ),
    );
    final s = spans.findSpanByName('saleor CheckoutLinesAdd')!;
    expect(s.status, SpanStatusCode.Error);
    final a = attrsOf(s);
    expect(a['saleor.error.code'], 'INSUFFICIENT_STOCK');
  });

  test('suppression skips spans', () async {
    await runWithoutSaleorInstrumentationAsync(() async {
      await tracedSaleor<String>(
        operationName: 'Products',
        invoke: () async => const SaleorCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('saleor '), isEmpty);
  });
}
