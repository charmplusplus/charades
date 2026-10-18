/** \file command_line.h
 * Defines functions for registering and parsing command line arguments.
 */

#ifndef CLARG_H_
#define CLARG_H_

#include <charm++.h>
#include <limits>
#include <map>
#include <sstream>
#include <string>
#include <vector>

// Should parse return a bool for success/failure? Errors maybe should abort
// but just print the error and return false?
class Parser {
public:
  virtual bool parse(std::string argument) const = 0;
  virtual void print() const = 0;
};

class AggregateParser : public Parser {
protected:
  std::vector<Parser*> parsers;
public:
  AggregateParser() {}

  void add_parser(Parser* p) {
    parsers.push_back(p);
  }

  bool parse(std::string argument) const {
    for (int i = 0; i < parsers.size(); i++) {
      if (parsers[i]->parse(argument)) {
        return true;
      }
    }
    return false;
  }

  void print() const {
    for (int i = 0; i < parsers.size(); i++) {
      parsers[i]->print();
    }
    CkPrintf("\n");
  }
};

/**
 * Read a whole option value into \p location, rejecting trailing characters.
 * Single-byte integers go through int: streaming into a uint8_t reads one
 * character, so "--start-events=10" would store '1' (49).
 */
template <typename ArgType>
bool read_value(const std::string& text, ArgType& location) {
  std::stringstream stream(text);
  stream >> location;
  return !stream.fail() && (stream >> std::ws).eof();
}

template <typename IntType>
bool read_byte_value(const std::string& text, IntType& location) {
  std::stringstream stream(text);
  long value;
  stream >> value;
  if (stream.fail() || !(stream >> std::ws).eof() ||
      value < std::numeric_limits<IntType>::min() ||
      value > std::numeric_limits<IntType>::max()) {
    return false;
  }
  location = static_cast<IntType>(value);
  return true;
}

inline bool read_value(const std::string& text, uint8_t& location) {
  return read_byte_value(text, location);
}

inline bool read_value(const std::string& text, int8_t& location) {
  return read_byte_value(text, location);
}

template <typename ArgType>
class Argument : public Parser {
private:
  std::string name, description;
  ArgType& location;

public:
  Argument(std::string n, std::string d, ArgType& l)
      : name(n), description(d), location(l) {}

  bool parse(std::string argument) const {
    std::stringstream stream(argument);
    std::string lhs, rhs;
    std::getline(stream, lhs, '=');
    std::getline(stream, rhs, '=');

    if (lhs != name) {
      return false;
    }
    // The option is ours: a missing or malformed value is an error, not an
    // unrecognized option, so the run cannot quietly use the default.
    if (rhs.length() == 0 || !read_value(rhs, location)) {
      CkPrintf("Error: --%s needs a valid value, got '%s'\n",
          name.c_str(), rhs.c_str());
      CkAbort("Argument parse error\n");
    }
    return true;
  }

  void print() const {
    CkPrintf("%24s: %s\n", name.c_str(), description.c_str());
  }
};

// Treating this as a parser might be weird or might be fine
// To merge multiple sets, we could just add this as a parser to a superset, but
// adding one entry for each argument in it's map
// Or we can just make a more proper composite set
// We want to preserve set names and order for printing
/**
 * Class for a set of arguments that can be read from the command line.
 */
class ArgumentSet : public AggregateParser {
private:
  std::string name;
  std::map<std::string, uint8_t> indices;

public:
  /**
   * \param n name of the arguments set (shown when using --help)
   */
  ArgumentSet(std::string n) : name(n) {}

  /**
   * Register a new command line argument to be parsed.
   * \param name name of the argument that will be used on the command line
   * \param desc description of the argument shown when using --help
   * \param loc the address where the parsed value should be stored
   */
  template <typename ArgType>
  void register_argument(std::string name, std::string desc, ArgType& loc) {
    if (indices.find(name) != indices.end()) {
      if (CkMyPe() == 0) {
        CkPrintf("Duplicate argument registration: %s\n", name.c_str());
        CkAbort("Argument parse error\n");
      }
    }
    indices[name] = parsers.size();
    add_parser(new Argument<ArgType>(name, desc, loc));
  }

  void print() const {
    CkPrintf("\n%s %s\n", std::string(25,'=').c_str(), name.c_str());
    AggregateParser::print();
  }
};

/** Add a new set of arguments for the simulator to parse */
void tw_add_arguments(ArgumentSet* args);
void parse_command_line(int argc, char** argv);

#endif
