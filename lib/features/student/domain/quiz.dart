/// Una pregunta del quiz «Pon a prueba lo que sabes».
class QuizQuestion {
  const QuizQuestion({
    required this.text,
    required this.options,
    required this.correct,
    required this.explanation,
  });

  final String text;
  final List<String> options;

  /// Posición de la respuesta correcta en [options].
  final int correct;

  /// Por qué es esa la respuesta: lo que la persona se lleva aunque haya fallado.
  final String explanation;
}

/// Las preguntas del quiz de sismo.
///
/// Salen de la regla que el colegio enseña —*agáchate, cúbrete y sujétate; sal
/// sin correr hasta el punto de encuentro*— y no de una fuente externa. Si el
/// comité de gestión del riesgo cambia el protocolo, estas preguntas se revisan
/// con él.
abstract final class SismoQuiz {
  static const String title = 'Sismo';

  static const List<QuizQuestion> questions = <QuizQuestion>[
    QuizQuestion(
      text: 'Estás en clase y empieza a temblar. ¿Qué haces primero?',
      options: <String>[
        'Salgo corriendo al patio',
        'Me agacho y me cubro bajo el pupitre',
        'Llamo a mi familia',
        'Me paro junto a la ventana',
      ],
      correct: 1,
      explanation: 'Correr mientras tiembla es la causa más común de golpes. '
          'Primero protégete; evacúa cuando pare.',
    ),
    QuizQuestion(
      text: 'Mientras tiembla, ¿dónde NO debes estar?',
      options: <String>[
        'Cerca de ventanas y estantes',
        'Bajo un pupitre firme',
        'Lejos de las vitrinas',
        'Agachado, con la cabeza cubierta',
      ],
      correct: 0,
      explanation: 'Los vidrios y los objetos que caen hieren más que el movimiento '
          'mismo. Aléjate de ventanas y estantes.',
    ),
    QuizQuestion(
      text: 'Ya pasó el temblor y se da la orden de evacuar. ¿Cómo sales?',
      options: <String>[
        'Corriendo para llegar primero',
        'Por donde veo menos gente',
        'Caminando, sin correr, por la ruta señalizada',
        'Esperando a que salgan todos',
      ],
      correct: 2,
      explanation: 'La ruta señalizada está revisada: es la más segura. Correr '
          'provoca caídas y empujones.',
    ),
    QuizQuestion(
      text: 'Estás en el patio cuando tiembla. ¿Qué haces?',
      options: <String>[
        'Me pego a la pared de un edificio',
        'Me quedo bajo un poste de luz',
        'Me refugio bajo un árbol',
        'Me alejo de edificios, postes y cables',
      ],
      correct: 3,
      explanation: 'En espacio abierto lo peligroso es lo que puede caer: muros, '
          'postes y cables. Busca un lugar despejado.',
    ),
    QuizQuestion(
      text: 'Llegaste al punto de encuentro. ¿Qué haces?',
      options: <String>[
        'Vuelvo al salón por mis cosas',
        'Me quedo con mi grupo y marco «Estoy a salvo»',
        'Me voy a casa sin avisar',
        'Busco a mis amigos de otros cursos',
      ],
      correct: 1,
      explanation: 'Tu docente tiene que contarte en la lista. Marcar «Estoy a salvo» '
          'además tranquiliza a tu familia.',
    ),
  ];
}
