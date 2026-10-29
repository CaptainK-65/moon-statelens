"""Independent reference learner, not a production inference dependency.

JSON stdin/stdout adapter around unmodified AALpy 2.0.0 public APIs.
File/process orchestration and result verification live in MoonBit .mbtx tools.
"""
import json
import sys
from importlib.metadata import version
from aalpy.automata import MealyMachine, MealyState
from aalpy.SULs import AutomatonSUL
from aalpy.oracles import PerfectKnowledgeEqOracle
from aalpy.learning_algs import run_Lstar


def learn(document):
    states = [MealyState(str(i)) for i in range(len(document['transitions']))]
    for state, row in zip(states, document['transitions']):
        for symbol, edge in zip(document['alphabet'], row):
            state.transitions[symbol] = states[edge['target']]
            state.output_fun[symbol] = edge['output']
    target = MealyMachine(states[document['initial']], states)
    sul = AutomatonSUL(target)
    learned = run_Lstar(document['alphabet'], sul,
                        PerfectKnowledgeEqOracle(document['alphabet'], sul, target),
                        automaton_type='mealy', print_level=0)
    return dict(format='moonstatelens.mealy', version=1,
                alphabet=document['alphabet'], initial=learned.states.index(learned.initial_state),
                transitions=[[dict(target=learned.states.index(s.transitions[a]), output=s.output_fun[a])
                              for a in document['alphabet']] for s in learned.states])


if __name__ == '__main__':
    request = json.load(sys.stdin)
    assert version('aalpy') == '2.0.0'
    print(json.dumps(dict(reference='AALpy', version=version('aalpy'),
                         models=[learn(m) for m in request['models']])))
