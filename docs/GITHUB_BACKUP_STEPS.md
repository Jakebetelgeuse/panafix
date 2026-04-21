# Subir Panafix a GitHub

## 1. Inicializar Git localmente

```powershell
cd C:\Users\Bella\StudioProjects\panafix
git init
git branch -M main
git add .
git commit -m "Initial backup of Panafix"
```

## 2. Crear repo en GitHub

Crea un repositorio privado, por ejemplo:

- `panafix`

## 3. Conectar el repo local con GitHub

Reemplaza `TU_USUARIO` por tu usuario:

```powershell
git remote add origin https://github.com/TU_USUARIO/panafix.git
git push -u origin main
```

## 4. En la Mac

```bash
git clone https://github.com/TU_USUARIO/panafix.git
cd panafix
flutter pub get
```

## 5. Recomendacion

- Usa repositorio privado
- Guarda aparte tus credenciales delicadas
- No subas `android/key.properties`
- No subas archivos `.jks`
