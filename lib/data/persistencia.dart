import 'base_datos.dart';
import 'repositorio_aula.dart';
import 'repositorio_conversaciones.dart';
import 'repositorio_corpus.dart';
import 'repositorio_docente.dart';

/// Punto unico de acceso a la base de datos local: agrupa los cuatro repositorios.
///
/// Es seguro usarla aunque no haya base de datos ([disponible] == false): todos
/// los repositorios devuelven valores vacios y la app funciona sin historial.
class Persistencia {
	Persistencia._(this.base)
		: aula = RepositorioAula(base),
			corpus = RepositorioCorpus(base),
			conversaciones = RepositorioConversaciones(base),
			docente = RepositorioDocente(base);

	final BaseDatos base;
	final RepositorioAula aula;
	final RepositorioCorpus corpus;
	final RepositorioConversaciones conversaciones;

	/// Credencial del docente para el panel de Configuracion.
	final RepositorioDocente docente;

	bool get disponible => base.disponible;

	/// Abre la base de datos real (SQLite). Nunca lanza errores.
	static Future<Persistencia> abrir() async =>
		Persistencia._(await BaseDatos.abrir());

	/// Persistencia vacia: pruebas unitarias y navegador.
	factory Persistencia.sinBaseDatos() =>
		Persistencia._(BaseDatos.sinBaseDatos());

	Future<void> cerrar() => base.cerrar();
}
