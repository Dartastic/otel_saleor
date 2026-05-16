// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_saleor_suppression.dart';

const _tracerName = 'dartastic_otel_libs_saleor';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class SaleorResult {
  const SaleorResult({
    this.itemCount,
    this.totalCount,
    this.channelSlug,
    this.warehouseId,
    this.orderStatus,
    this.paymentChargeStatus,
    this.checkoutStatus,
    this.totalAmountMinor,
    this.currency,
    this.errorCode,
    this.requestId,
    this.statusCode,
  });

  /// `edges.length` in connection responses.
  final int? itemCount;

  /// `totalCount` from connections.
  final int? totalCount;

  /// Saleor channel slug — drives pricing, currency, listings.
  final String? channelSlug;

  /// Warehouse id for inventory/fulfillment ops.
  final String? warehouseId;

  /// `DRAFT` / `UNCONFIRMED` / `UNFULFILLED` / `PARTIALLY_FULFILLED` /
  /// `FULFILLED` / `RETURNED` / `CANCELED` / `EXPIRED`.
  final String? orderStatus;

  /// `NOT_CHARGED` / `PENDING` / `PARTIALLY_CHARGED` / `FULLY_CHARGED`
  /// / `PARTIALLY_REFUNDED` / `FULLY_REFUNDED` / `CANCELLED` /
  /// `REFUSED`.
  final String? paymentChargeStatus;

  /// `complete` / `requires_action` from checkoutComplete responses.
  final String? checkoutStatus;

  /// Total in minor units.
  final int? totalAmountMinor;

  /// ISO 4217.
  final String? currency;

  /// Saleor GraphQL `errors[0].code` (e.g. `INSUFFICIENT_STOCK`).
  final String? errorCode;

  /// `X-Saleor-Trace-Id` / opaque.
  final String? requestId;

  final int? statusCode;
}

class SaleorCallResult<T> {
  const SaleorCallResult({required this.value, this.result});
  final T value;
  final SaleorResult? result;
}

/// Wraps a Saleor GraphQL call in a CLIENT span. [operationName] is
/// the GraphQL operationName.
Future<T> tracedSaleor<T>({
  required String operationName,
  required Future<SaleorCallResult<T>> Function() invoke,
  String? operationType,
  String? channelSlug,
}) async {
  if (saleorInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'saleor',
    'rpc.method': operationName,
    'graphql.operation.name': operationName,
    'saleor.operation': operationName,
  };
  if (operationType != null) m['graphql.operation.type'] = operationType;
  if (channelSlug != null) m['saleor.channel.slug'] = channelSlug;

  final span = _tracer().startSpan(
    'saleor $operationName',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.itemCount != null) {
        extras.add(OTel.attributeInt(
          'saleor.item_count',
          r.result!.itemCount!,
        ));
      }
      if (r.result!.totalCount != null) {
        extras.add(OTel.attributeInt(
          'saleor.total_count',
          r.result!.totalCount!,
        ));
      }
      if (r.result!.channelSlug != null) {
        extras.add(OTel.attributeString(
          'saleor.channel.slug',
          r.result!.channelSlug!,
        ));
      }
      if (r.result!.warehouseId != null) {
        extras.add(OTel.attributeString(
          'saleor.warehouse.id',
          r.result!.warehouseId!,
        ));
      }
      if (r.result!.orderStatus != null) {
        extras.add(OTel.attributeString(
          'saleor.order.status',
          r.result!.orderStatus!,
        ));
        if (r.result!.orderStatus == 'CANCELED' ||
            r.result!.orderStatus == 'EXPIRED') {
          span.setStatus(
            SpanStatusCode.Error,
            'Saleor order ${r.result!.orderStatus}',
          );
        }
      }
      if (r.result!.paymentChargeStatus != null) {
        extras.add(OTel.attributeString(
          'saleor.payment.charge_status',
          r.result!.paymentChargeStatus!,
        ));
      }
      if (r.result!.checkoutStatus != null) {
        extras.add(OTel.attributeString(
          'saleor.checkout.status',
          r.result!.checkoutStatus!,
        ));
      }
      if (r.result!.totalAmountMinor != null) {
        extras.add(OTel.attributeInt(
          'saleor.amount.total.minor',
          r.result!.totalAmountMinor!,
        ));
      }
      if (r.result!.currency != null) {
        extras.add(OTel.attributeString(
          'saleor.currency',
          r.result!.currency!,
        ));
      }
      if (r.result!.errorCode != null) {
        extras.add(OTel.attributeString(
          'saleor.error.code',
          r.result!.errorCode!,
        ));
        span.setStatus(
          SpanStatusCode.Error,
          'Saleor error ${r.result!.errorCode}',
        );
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'saleor.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Saleor HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
