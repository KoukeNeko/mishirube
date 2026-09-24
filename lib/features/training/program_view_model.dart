import '../../app/view_model.dart';
import '../../backend/seed/program_templates.dart';
import '../../domain/domain.dart';

/// Programs: the one running, where it stands, and changes to any.
class ProgramViewModel extends ViewModel {
  ProgramViewModel(super.backend);

  List<Program> get programs => backend.program.all();

  List<ProgramTemplate> get templates => programTemplates;

  Program? byId(String id) => backend.program.byId(id);

  /// Where the running program stands; null when none runs.
  ProgramProgress? get progress => backend.program.progress();

  ProgramProgress progressOf(Program program) =>
      backend.program.progressOf(program);

  Program create(String name) => backend.program.create(name);

  Program createFrom(ProgramTemplate template) =>
      backend.program.createFrom(template);

  void rename(Program program, String name) =>
      backend.program.save(program.copyWith(name: name));

  void setSchedule(Program program, ProgramSchedule schedule) =>
      backend.program.setSchedule(program, schedule);

  void setWeekday(Program program, int position, int weekday) =>
      backend.program.setWeekday(program, position, weekday);

  void move(Program program, int from, int to) =>
      backend.program.move(program, from, to);

  void remove(Program program, int position) =>
      backend.program.remove(program, position);

  Routine addNew(Program program, String name) =>
      backend.program.addNew(program, name);

  Routine addCopy(Program program, Routine routine) =>
      backend.program.addCopy(program, routine);

  void start(Program program) => backend.program.start(program);

  void end(Program program) => backend.program.end(program);

  void delete(Program program) => backend.program.delete(program.id);

  void skipNext() => backend.program.skipNext();
}
