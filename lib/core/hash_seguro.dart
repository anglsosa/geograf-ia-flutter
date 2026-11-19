import 'dart:convert';
import 'dart:math';

/// Hash seguro de contrasenas sin paquetes externos (100% offline).
///
/// Implementa SHA-256 (FIPS 180-4) en Dart puro y lo usa con sal aleatoria y
/// muchas iteraciones, igual que hacen los proveedores de autenticacion reales:
/// en la base de datos NUNCA se guarda la contrasena, solo su huella.
///
/// Solo usa operaciones de 32 bits con mascara, por lo que da el mismo
/// resultado en el telefono (Dart VM) y en el previsualizador web (JavaScript).
class HashSeguro {
	HashSeguro._();

	static const int _mascara32 = 0xFFFFFFFF;

	static const List<int> _k = <int>[
		0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
		0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
		0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
		0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
		0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
		0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
		0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
		0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
		0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
		0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
		0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
	];

	static int _rotarDerecha(int x, int n) =>
		((x >> n) | (x << (32 - n))) & _mascara32;

	/// SHA-256 de una lista de bytes; devuelve los 32 bytes del resumen.
	static List<int> sha256Bytes(List<int> datos) {
		final int largoBits = datos.length * 8;
		final List<int> mensaje = List<int>.from(datos)..add(0x80);
		while (mensaje.length % 64 != 56) {
			mensaje.add(0);
		}
		// Largo del mensaje en bits como entero de 64 bits big-endian. Se arma
		// con divisiones para no depender de enteros de 64 bits (web).
		final int alto = largoBits ~/ 0x100000000;
		final int bajo = largoBits % 0x100000000;
		for (final int parte in <int>[alto, bajo]) {
			mensaje
				..add((parte >> 24) & 0xFF)
				..add((parte >> 16) & 0xFF)
				..add((parte >> 8) & 0xFF)
				..add(parte & 0xFF);
		}

		final List<int> h = <int>[
			0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
			0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
		];
		final List<int> w = List<int>.filled(64, 0);

		for (int bloque = 0; bloque < mensaje.length; bloque += 64) {
			for (int t = 0; t < 16; t++) {
				final int i = bloque + (t * 4);
				w[t] = ((mensaje[i] << 24) |
						(mensaje[i + 1] << 16) |
						(mensaje[i + 2] << 8) |
						mensaje[i + 3]) &
					_mascara32;
			}
			for (int t = 16; t < 64; t++) {
				final int s0 = _rotarDerecha(w[t - 15], 7) ^
					_rotarDerecha(w[t - 15], 18) ^
					(w[t - 15] >> 3);
				final int s1 = _rotarDerecha(w[t - 2], 17) ^
					_rotarDerecha(w[t - 2], 19) ^
					(w[t - 2] >> 10);
				w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & _mascara32;
			}

			int a = h[0];
			int b = h[1];
			int c = h[2];
			int d = h[3];
			int e = h[4];
			int f = h[5];
			int g = h[6];
			int hh = h[7];

			for (int t = 0; t < 64; t++) {
				final int s1 = _rotarDerecha(e, 6) ^
					_rotarDerecha(e, 11) ^
					_rotarDerecha(e, 25);
				final int ch = (e & f) ^ ((~e & _mascara32) & g);
				final int temp1 = (hh + s1 + ch + _k[t] + w[t]) & _mascara32;
				final int s0 = _rotarDerecha(a, 2) ^
					_rotarDerecha(a, 13) ^
					_rotarDerecha(a, 22);
				final int maj = (a & b) ^ (a & c) ^ (b & c);
				final int temp2 = (s0 + maj) & _mascara32;

				hh = g;
				g = f;
				f = e;
				e = (d + temp1) & _mascara32;
				d = c;
				c = b;
				b = a;
				a = (temp1 + temp2) & _mascara32;
			}

			h[0] = (h[0] + a) & _mascara32;
			h[1] = (h[1] + b) & _mascara32;
			h[2] = (h[2] + c) & _mascara32;
			h[3] = (h[3] + d) & _mascara32;
			h[4] = (h[4] + e) & _mascara32;
			h[5] = (h[5] + f) & _mascara32;
			h[6] = (h[6] + g) & _mascara32;
			h[7] = (h[7] + hh) & _mascara32;
		}

		final List<int> salida = <int>[];
		for (final int valor in h) {
			salida
				..add((valor >> 24) & 0xFF)
				..add((valor >> 16) & 0xFF)
				..add((valor >> 8) & 0xFF)
				..add(valor & 0xFF);
		}
		return salida;
	}

	/// SHA-256 de un texto (UTF-8) en hexadecimal de 64 caracteres.
	static String sha256Hex(String texto) => aHex(sha256Bytes(utf8.encode(texto)));

	/// Convierte bytes a texto hexadecimal en minusculas.
	static String aHex(List<int> bytes) =>
		bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();

	/// Sal aleatoria criptografica (16 bytes = 32 caracteres hex).
	static String generarSal() {
		final Random azar = Random.secure();
		return aHex(List<int>.generate(16, (_) => azar.nextInt(256)));
	}

	/// Huella de la contrasena: SHA-256 iterado con sal (estiramiento de clave).
	/// Hace mas lento probar contrasenas por fuerza bruta si alguien copia la base.
	static String huellaContrasena(
		String contrasena,
		String sal,
		int iteraciones,
	) {
		final List<int> bytesSal = utf8.encode(sal);
		List<int> resumen = sha256Bytes(<int>[...bytesSal, ...utf8.encode(contrasena)]);
		for (int i = 1; i < iteraciones; i++) {
			resumen = sha256Bytes(<int>[...resumen, ...bytesSal]);
		}
		return aHex(resumen);
	}

	/// Compara dos huellas en tiempo constante (no revela cuantos caracteres coinciden).
	static bool sonIguales(String a, String b) {
		if (a.length != b.length) {
			return false;
		}
		int diferencia = 0;
		for (int i = 0; i < a.length; i++) {
			diferencia |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
		}
		return diferencia == 0;
	}
}
