class_name Job

# Enum for job types
enum JobType {
	CAREER,
	COLLEGE
}

# Properties
var salary: int
var bonus_number: int
var job_type: JobType

# Constructor
func _init(_type: JobType = JobType.CAREER, _salary: int = 100, _bonus: int = 10):
	job_type = _type
	salary = _salary
	bonus_number = _bonus
