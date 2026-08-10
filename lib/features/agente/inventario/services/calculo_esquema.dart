/// Cálculo de los montos de un esquema de pago sobre el precio de lista de una
/// unidad. Espejo de `src/utils/escalonadoUtils.ts` del panel: es la MISMA
/// aritmética que la oferta digital y el PDF comercial, y tiene que dar el
/// mismo número que le van a firmar al cliente.
///
/// Sin UI a propósito (`services/`): esto se prueba con aritmética, no con
/// widgets.
library;

import 'package:sozu_agente_app/features/agente/inventario/ports/inventario_port.dart';

/// Montos y porcentajes resueltos de un esquema para un precio concreto.
class MontosEsquema {
  /// Precio de lista con el descuento o aumento del esquema aplicado.
  final double precioFinal;

  final double enganche;
  final double mensualidad;
  final double mensualidadesTotal;
  final double entrega;
  final int meses;
  final double porcentajeMensualidades;
  final double porcentajeEntrega;

  const MontosEsquema({
    this.precioFinal = 0,
    this.enganche = 0,
    this.mensualidad = 0,
    this.mensualidadesTotal = 0,
    this.entrega = 0,
    this.meses = 0,
    this.porcentajeMensualidades = 0,
    this.porcentajeEntrega = 0,
  });
}

/// Meses completos entre dos fechas (calendario, no días).
int mesesEntreFechas(DateTime desde, DateTime hasta) {
  final meses =
      (hasta.year - desde.year) * 12 + (hasta.month - desde.month);
  return meses < 0 ? 0 : meses;
}

/// Mensualidades RESTANTES hasta la entrega: los meses que faltan menos 1, ya
/// que el mes de entrega es el pago a escrituración y no una mensualidad.
///
/// El servidor ya manda este número por desarrollo (`meses_mensualidades`);
/// esta función existe para calcularlo cuando solo se tiene la fecha.
int mesesMensualidadesRestantes(String? fechaEntrega, {DateTime? desde}) {
  if (fechaEntrega == null) return 0;
  final entrega = DateTime.tryParse(fechaEntrega);
  if (entrega == null) return 0;
  final meses = mesesEntreFechas(desde ?? DateTime.now(), entrega) - 1;
  return meses < 0 ? 0 : meses;
}

/// Tramos con su número de mensualidades resuelto: el que tiene `fecha_limite`
/// se recalcula contra hoy, porque su plazo es una fecha, no un conteo.
List<TramoMensualidad> tramosResueltos(
  List<TramoMensualidad> tramos, {
  DateTime? referencia,
}) {
  final hoy = referencia ?? DateTime.now();
  return tramos.map((t) {
    final limite = t.fechaLimite == null
        ? null
        : DateTime.tryParse(t.fechaLimite!);
    if (limite == null) return t;
    return TramoMensualidad(
      montoMensualidadCentavos: t.montoMensualidadCentavos,
      numeroMensualidades: mesesEntreFechas(hoy, limite),
      fechaLimite: t.fechaLimite,
    );
  }).toList(growable: false);
}

/// Montos de un esquema.
///
/// [mesesEfectivos] son las mensualidades que de verdad caben de hoy a la
/// entrega. Con 0 se conservan los valores guardados del esquema. Al acortarse
/// el plazo, la mensualidad NO cambia: baja el porcentaje de mensualidades y el
/// pago a la entrega absorbe la diferencia.
MontosEsquema montosDeEsquema(
  EsquemaPago esquema,
  double precioLista, {
  int mesesEfectivos = 0,
  DateTime? referencia,
}) {
  if (esquema.esEscalonadoMontoFijo) {
    return _escalonado(
      esquema,
      precioLista,
      mesesEfectivos,
      referencia: referencia,
    );
  }
  return _porcentajes(esquema, precioLista, mesesEfectivos);
}

/// Esquema por porcentajes: la mensualidad se deriva del % y del plazo original.
MontosEsquema _porcentajes(
  EsquemaPago e,
  double precioLista,
  int mesesEfectivos,
) {
  final precioFinal = precioLista * (1 + e.porcentajeDescuentoAumento / 100);
  final mesesOriginales = e.numeroMensualidades;
  // Un esquema sin porcentaje de mensualidades (contado, contra entrega) no se
  // recalcula contra la fecha de entrega: no tiene mensualidades que acortar.
  final efectivos = e.porcentajeMensualidades > 0 ? mesesEfectivos : 0;
  // Nunca más meses de los pactados: la entrega puede estar lejos, el esquema no
  // se estira por eso.
  final meses = efectivos > 0
      ? (efectivos < mesesOriginales ? efectivos : mesesOriginales)
      : mesesOriginales;

  final mensualidad = mesesOriginales > 0
      ? (precioFinal * (e.porcentajeMensualidades / 100)) / mesesOriginales
      : 0.0;

  final pctMensualidades = mesesOriginales > 0
      ? e.porcentajeMensualidades * (meses / mesesOriginales)
      : e.porcentajeMensualidades;
  final pctEntrega =
      e.porcentajeEntrega + (e.porcentajeMensualidades - pctMensualidades);

  return MontosEsquema(
    precioFinal: precioFinal,
    enganche: precioFinal * (e.porcentajeEnganche / 100),
    mensualidad: mensualidad,
    mensualidadesTotal: mensualidad * meses,
    entrega: precioFinal * (pctEntrega / 100),
    meses: meses,
    porcentajeMensualidades: pctMensualidades,
    porcentajeEntrega: pctEntrega,
  );
}

/// Esquema escalonado con monto fijo: el monto mensual está en los tramos (en
/// centavos) y la entrega es el residuo, no un porcentaje guardado.
MontosEsquema _escalonado(
  EsquemaPago e,
  double precioLista,
  int mesesEfectivos, {
  DateTime? referencia,
}) {
  final precioFinal = precioLista * (1 + e.porcentajeDescuentoAumento / 100);
  final enganche = precioFinal * (e.porcentajeEnganche / 100);

  int meses;
  double mensualidad;
  double mensualidadesTotal;

  if (!e.esManual && mesesEfectivos > 0) {
    // Dinámico: monto fijo del primer tramo con monto, por los meses que de
    // verdad quedan hasta la entrega.
    meses = mesesEfectivos;
    mensualidad = _montoFijo(e.tramos);
    mensualidadesTotal = mensualidad * meses;
  } else {
    final tramos = tramosResueltos(e.tramos, referencia: referencia);
    meses = tramos.fold(0, (s, t) => s + t.numeroMensualidades);
    mensualidadesTotal = tramos.fold(
      0,
      (s, t) => s + (t.montoMensualidadCentavos / 100) * t.numeroMensualidades,
    );
    mensualidad = meses > 0 ? mensualidadesTotal / meses : 0;
  }

  final entrega = precioFinal - enganche - mensualidadesTotal;
  final entregaSaneada = entrega < 0 ? 0.0 : entrega;

  return MontosEsquema(
    precioFinal: precioFinal,
    enganche: enganche,
    mensualidad: mensualidad,
    mensualidadesTotal: mensualidadesTotal,
    entrega: entregaSaneada,
    meses: meses,
    porcentajeMensualidades: precioFinal > 0
        ? (mensualidadesTotal / precioFinal) * 100
        : 0,
    porcentajeEntrega: precioFinal > 0
        ? (entregaSaneada / precioFinal) * 100
        : 0,
  );
}

/// Monto mensual (en pesos) del primer tramo que trae uno.
double _montoFijo(List<TramoMensualidad> tramos) {
  for (final t in tramos) {
    if (t.montoMensualidadCentavos > 0) return t.montoMensualidadCentavos / 100;
  }
  return 0;
}
