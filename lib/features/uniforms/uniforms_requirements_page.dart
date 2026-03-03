import 'package:flutter/material.dart';

import '../../shared/widgets/app_scaffold.dart';
import 'domain/uniforms_requirements_content.dart';

class UniformsRequirementsPage extends StatelessWidget {
  const UniformsRequirementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Requisitos del proveedor',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            UniformsRequirementsContent.intro,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                UniformsRequirementsContent.noColumnRule,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('Tallas permitidas', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...UniformsRequirementsContent.allowedAdultSizes
                  .map((size) => Chip(label: Text('Adulto: $size'))),
              ...UniformsRequirementsContent.allowedKidsSizes
                  .map((size) => Chip(label: Text('Niño: $size'))),
            ],
          ),
          const SizedBox(height: 14),
          Text('Género permitido', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: UniformsRequirementsContent.allowedGenders
                .map((gender) => Chip(label: Text(gender)))
                .toList(),
          ),
          const SizedBox(height: 14),
          Text('Ejemplo de tabla', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('No.')),
                DataColumn(label: Text('Nombre')),
                DataColumn(label: Text('Número #')),
                DataColumn(label: Text('Talla')),
                DataColumn(label: Text('Género')),
              ],
              rows: const [
                DataRow(
                  cells: [
                    DataCell(Text('1')),
                    DataCell(Text('Eduardo Acosta')),
                    DataCell(Text('10')),
                    DataCell(Text('L')),
                    DataCell(Text('H')),
                  ],
                ),
                DataRow(
                  cells: [
                    DataCell(Text('2')),
                    DataCell(Text('Isis Azueta')),
                    DataCell(Text('22')),
                    DataCell(Text('M')),
                    DataCell(Text('M')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                UniformsRequirementsContent.disclaimer,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
