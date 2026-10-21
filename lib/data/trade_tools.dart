import 'package:flutter/material.dart';

class TradeTool {
  const TradeTool({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String category;
}

class TradeInfo {
  const TradeInfo({
    required this.name,
    required this.tagline,
    required this.icon,
    required this.categories,
    required this.tools,
  });

  final String name;
  final String tagline;
  final IconData icon;
  final List<String> categories;
  final List<TradeTool> tools;
}

const electrical = TradeInfo(
  name: 'Electrical',
  tagline: 'Sizing, protection & power',
  icon: Icons.bolt_rounded,
  categories: ['Sizing', 'Protection', 'Power', 'Reference', 'Site'],
  tools: [
    TradeTool(
      id: 'elec_cable_size',
      name: 'Cable Size Calculator',
      description: 'Size cables by load, length & installation',
      icon: Icons.bolt_rounded,
      category: 'Sizing',
    ),
    TradeTool(
      id: 'elec_voltage_drop',
      name: 'Voltage Drop',
      description: 'Check drop against BS 7671 limits',
      icon: Icons.south_east_rounded,
      category: 'Sizing',
    ),
    TradeTool(
      id: 'elec_breaker',
      name: 'Breaker / MCB / MCCB Selector',
      description: 'Match breaker to load & cable',
      icon: Icons.shield_outlined,
      category: 'Protection',
    ),
    TradeTool(
      id: 'elec_load',
      name: 'Load Calculator',
      description: 'Sum loads by phase and demand factor',
      icon: Icons.bar_chart_rounded,
      category: 'Power',
    ),
    TradeTool(
      id: 'elec_phase_converter',
      name: 'Single / 3-Phase Converter',
      description: 'kW, kVA, A conversions',
      icon: Icons.sync_rounded,
      category: 'Power',
    ),
    TradeTool(
      id: 'elec_generator',
      name: 'Generator Sizing',
      description: 'Size gen for load kVA + start surge',
      icon: Icons.power_rounded,
      category: 'Sizing',
    ),
    TradeTool(
      id: 'elec_solar',
      name: 'Inverter / Battery / Solar',
      description: 'Off-grid system sizing',
      icon: Icons.wb_sunny_outlined,
      category: 'Power',
    ),
    TradeTool(
      id: 'elec_transformer',
      name: 'Transformer Sizing',
      description: 'kVA, voltage ratio, losses',
      icon: Icons.view_in_ar_outlined,
      category: 'Sizing',
    ),
    TradeTool(
      id: 'elec_pf_correction',
      name: 'Power Factor Correction',
      description: 'Capacitor bank sizing',
      icon: Icons.show_chart_rounded,
      category: 'Power',
    ),
    TradeTool(
      id: 'elec_earthing',
      name: 'Earthing Calculator',
      description: 'Earth rod, plate & loop impedance',
      icon: Icons.anchor_rounded,
      category: 'Protection',
    ),
    TradeTool(
      id: 'elec_conduit_fill',
      name: 'Conduit Fill',
      description: 'Cable count vs conduit size',
      icon: Icons.inventory_2_outlined,
      category: 'Sizing',
    ),
    TradeTool(
      id: 'elec_lighting',
      name: 'Lighting Design',
      description: 'Lux level, lumens, layout',
      icon: Icons.lightbulb_outline_rounded,
      category: 'Sizing',
    ),
    TradeTool(
      id: 'elec_motor',
      name: 'Motor Tools',
      description: 'FLA, starting current, cable',
      icon: Icons.memory_rounded,
      category: 'Power',
    ),
    TradeTool(
      id: 'elec_fuel_vs_grid',
      name: 'Fuel vs Grid Cost',
      description: 'Gen vs utility cost comparison',
      icon: Icons.local_gas_station_outlined,
      category: 'Power',
    ),
    TradeTool(
      id: 'elec_colour_codes',
      name: 'Colour Codes',
      description: 'BS, IEC, NEC wire colours',
      icon: Icons.palette_outlined,
      category: 'Reference',
    ),
    TradeTool(
      id: 'elec_testing_log',
      name: 'Testing Log',
      description: 'Record insulation, continuity tests',
      icon: Icons.assignment_outlined,
      category: 'Site',
    ),
  ],
);
