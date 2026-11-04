// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_saleor/otel_saleor.dart';

/// Traces Saleor GraphQL calls with OpenTelemetry.
///
/// `otel_saleor` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Saleor GraphQL call in
/// [tracedSaleor]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'saleor-example');

  // Wraps a Saleor GraphQL call in a CLIENT span.
  final saleorId = await tracedSaleor<String>(
    operationName: 'example',
    operationType: 'standard',
    channelSlug: 'orders',
    invoke: () async {
      // Make the Saleor GraphQL call here, then report what it returned.
      const id = 'saleor_8f3a2c';
      return const SaleorCallResult(
          value: id,
          result: SaleorResult(
              itemCount: 3,
              totalCount: 3,
              channelSlug: 'orders',
              warehouseId: 'warehouse_8f3a2c',
              orderStatus: 'DRAFT',
              paymentChargeStatus: 'NOT_CHARGED',
              checkoutStatus: 'complete',
              totalAmountMinor: 1999,
              currency: 'usd',
              errorCode: 'errors[0].code',
              requestId: 'request_8f3a2c',
              statusCode: 200));
    },
  );
  OTelLog.info('tracedSaleor returned $saleorId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutSaleorInstrumentationAsync.
  await runWithoutSaleorInstrumentationAsync(
    () => tracedSaleor<String>(
      operationName: 'example',
      operationType: 'standard',
      channelSlug: 'orders',
      invoke: () async {
        const id = 'saleor_8f3a2c';
        return const SaleorCallResult(
            value: id,
            result: SaleorResult(
                itemCount: 3,
                totalCount: 3,
                channelSlug: 'orders',
                warehouseId: 'warehouse_8f3a2c',
                orderStatus: 'DRAFT',
                paymentChargeStatus: 'NOT_CHARGED',
                checkoutStatus: 'complete',
                totalAmountMinor: 1999,
                currency: 'usd',
                errorCode: 'errors[0].code',
                requestId: 'request_8f3a2c',
                statusCode: 200));
      },
    ),
  );

  await OTel.shutdown();
}
