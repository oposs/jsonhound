#| Provides a mechanism for specifying a disjunction of types,
#| allowing for the types to be fully retrieved.
class Either {
    has @.either-types;

    method ACCEPTS($topic) {
        $topic ~~ any(@!either-types)
    }

    method ^parameterize($, *@either-types) {
        Either.new(:@either-types)
    }

    method ^accepts_type(|c) {
        c[1].DEFINITE
    }
}
BEGIN Metamodel::Primitives.configure_type_checking(Either, (Either, Any, Mu), :call_accepts);