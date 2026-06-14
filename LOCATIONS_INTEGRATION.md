# Integración de Ubicaciones en Home Player

## 📍 Carrusel de Ubicaciones

Para mostrar el carrusel de ubicaciones en el Home del player, agrega esto a `HomeView.swift`:

### 1. Importar componentes
```swift
import AdminFeature  // Agrega si no existe
```

### 2. Estado para ubicaciones
En el ViewModel o en la vista, agrega:
```swift
@State private var locations: [AdminLocation] = []

private let locationRepository: LocationRepositoryProtocol
```

### 3. Cargar ubicaciones
En el `.task` de la vista:
```swift
.task {
    do {
        let useCase = FetchLocationsUseCase(repository: locationRepository)
        locations = try await useCase.execute()
    } catch {
        print("Error loading locations: \(error)")
    }
}
```

### 4. Agregar el carrusel a la UI
En el `ScrollView` de `HomeView`, agrega donde corresponda:

```swift
if !locations.isEmpty {
    LocationsCarouselView(
        locations: locations,
        onLocationTap: { location in
            // Acción al tocar una ubicación
            print("Tapped location: \(location.address)")
        }
    )
}
```

---

## 🗄️ CoreData Setup

Debes agregar la entidad `LocationEntity` al modelo de datos:

### Entidad: LocationEntity

```
Entity Name: LocationEntity
Attributes:
  - id: String (Required)
  - address: String (Optional)
  - city: String (Optional)
  - country: String (Optional)
  - latitude: Double (Required)
  - longitude: Double (Required)
  - createdAt: Date (Optional)
```

---

## 🔌 Inyección de Dependencias

Si usas el `AdminDependencyFactory`, obtén el repositorio así:

```swift
let repository = AdminDependencyFactory().makeLocationRepository(context: managedObjectContext)
```

---

## 📝 Ejemplo Completo

```swift
struct HomeView: View {
    @State private var locations: [AdminLocation] = []
    @Environment(\.managedObjectContext) private var context

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // ... otros contenidos ...

                // Carrusel de ubicaciones
                if !locations.isEmpty {
                    LocationsCarouselView(
                        locations: locations,
                        onLocationTap: { location in
                            print("Selected: \(location.address)")
                        }
                    )
                }

                // ... más contenidos ...
            }
        }
        .task {
            await loadLocations()
        }
    }

    private func loadLocations() async {
        do {
            let factory = AdminDependencyFactory()
            let useCase = factory.makeFetchLocationsUseCase(context: context)
            locations = try await useCase.execute()
        } catch {
            print("Error: \(error)")
        }
    }
}
```

---

## ✅ Requisitos

- [ ] Ubicación CoreData agregada al modelo
- [ ] `LocationsCarouselView` importada
- [ ] Estado de ubicaciones en la vista
- [ ] Task para cargar ubicaciones en el load
- [ ] Carrusel agregado a la UI donde corresponda
