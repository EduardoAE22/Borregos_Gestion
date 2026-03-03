# Borregos Gestion

App Flutter para gestion deportiva/operativa de Borregos (sede Progreso), con backend en Supabase.

## Requisitos

- Flutter SDK (canal estable)
- Dart SDK (incluido con Flutter)
- Proyecto de Supabase activo

Verifica instalacion:

```bash
flutter --version
flutter doctor
```

## Setup Local

1. Instala dependencias:

```bash
flutter pub get
```

2. Ejecuta app (web) con variables requeridas:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=tu_anon_key
```

La app valida esas variables al iniciar.  
Si faltan, muestra pantalla **Config faltante** y en debug imprime el motivo.

## Supabase Migrations

Este repo versiona SQL en `supabase/migrations/`.

Orden recomendado:

1. Ejecutar schema base y rls base:
   - `supabase/schema.sql`
   - `supabase/rls.sql`
2. Ejecutar migraciones en orden por timestamp (`YYYYMMDD...`).
3. Confirmar recarga de PostgREST (`notify pgrst, 'reload schema';` ya viene en migraciones clave).

## Roles Esperados

Roles en `public.profiles.role`:

- `super_admin`
- `coach`
- `viewer`

Comportamiento:

- `super_admin` y `coach`: escritura en modulos operativos.
- `viewer`: solo lectura donde aplique; algunos modulos (captura jugadas) quedan bloqueados por permisos.

## Storage Buckets Esperados

- `player_photos` (privado)
  - Se guarda `photo_path` / `photo_thumb_path` en DB.
  - UI usa signed URLs con cache en memoria.
- `payment_receipts` (privado)
  - Recibos de pagos con signed URLs para visualizacion.

Las policies de `storage.objects` para ambos buckets estan versionadas en migraciones y restringidas a `authenticated` con rol `super_admin`/`coach` para operaciones sensibles.

## Calidad y Pruebas

Analisis estatico:

```bash
dart analyze
```

Tests:

```bash
flutter test
```

## Notas de Entrega

- No subir artefactos locales: `build/`, `.dart_tool/`, `coverage/`, `*.zip`.
- Mantener secretos fuera del codigo; usar `--dart-define`.
