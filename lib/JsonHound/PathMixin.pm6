#| Mixed in to found pieces of the document, carrying the path that they are
#| located at.
role JsonHound::PathMixin {
    has Str $.path is required;
}
