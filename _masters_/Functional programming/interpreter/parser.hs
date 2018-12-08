module Parser where

import Text.Read
import Debug.Trace
import System.IO.Unsafe
import Data.Unique

import Lexer


data Env = Env
    { tokens    :: [Token]
    , stack     :: [Int]
    , nodes     :: [Node]
    } deriving (Show)

-- ================================================
-- =================  Stack ops  ==================
-- ================================================
toInt :: String -> Int
toInt val = read $ val :: Int


binOp :: (Int -> Int -> Int) -> Env -> Env
binOp operation e = e { stack = binOpResult : modStack }
    where n1 = stack e !! 0
          n2 = stack e !! 1 
          binOpResult = operation n2 n1 
          modStack = tail $ tail (stack e)

addOp e = binOp (+) e
subOp e = binOp (-) e
mulOp e = binOp (*) e
divOp e = binOp (div) e

pushOp e token = e { stack = intVal : (stack e) }
    where intVal = toInt $ v token

nextToken e = e { tokens = tail $ tokens e }


-- ================================================
-- =================  Node ops  ===================
-- ================================================
data Node = Node 
    { val       :: String
    , childs    :: [Node]
    , nodeId    :: Int
    } deriving (Show, Eq)

uid uniqueId = hashUnique $ unsafePerformIO uniqueId


makeLeafNode val nodeId = Node { val = val, childs = [], nodeId = nodeId }


makeBinaryNode val e = e { nodes = newNode : modNodes }
    where modNodes = tail $ tail $ nodes e
          n1 = nodes e !! 1
          n2 = nodes e !! 0
          newNode = Node { val = val
                         , childs = [n1, n2]
                         , nodeId = uid newUnique }


makeTernaryNode val extraNodeVal e = e { nodes = newNode : modNodes }
    where modNodes = tail $ tail $ nodes e
          n1 = nodes e !! 1
          n2 = nodes e !! 0
          nExtra = makeLeafNode extraNodeVal (uid newUnique)
          newNode = Node { val = val
                         , childs = [nExtra, n1, n2]
                         , nodeId = uid newUnique }


makeNodeWithChild val childVal e = e { nodes = newNode : (nodes e) }
    where child = makeLeafNode childVal (uid newUnique)
          newNode = Node { val = val
                         , childs = [child]
                         , nodeId = uid newUnique }


makeNodeFBracket e = e { nodes = newNode : modNodes}
    where modNodes = tail $ nodes e
          nE = nodes e !! 0
          nLeftParen = makeLeafNode "(" (uid newUnique)
          nRightParen = makeLeafNode ")" (uid newUnique)
          newNode = Node { val = "F"
                         , childs = [nLeftParen, nE, nRightParen]
                         , nodeId = uid newUnique }


-- ================================================
-- =================   Parser   ===================
-- ================================================
-- <E> ::= <T> <E’>
-- <T> ::= <F> <T’>
-- <E’> ::= + <T> <E’> | - <T> <E’> | e
-- <T’> ::= * <F> <T’> | / <F> <T’> | e
-- <F> ::= <number> | <var> | ( <E> ) | - <F>


-- <E> ::= <T> <E’>
parse_E :: Env -> Env
parse_E e = 
    makeBinaryNode "E" (parse_E1 $ parse_T e)

-- <T> ::= <F> <T’>.
parse_T :: Env -> Env
parse_T e =
    makeBinaryNode "T" (parse_T1 $ parse_F e)

-- <E’> ::= + <T> <E’> | - <T> <E’> | e
parse_E1 :: Env -> Env
parse_E1 e = 
    let token = head $ tokens e
        op = v $ token
    in case op of
        "+" -> makeTernaryNode "E1" "+" (parse_E1 $ addOp $ parse_T $ nextToken e)
        "-" -> makeTernaryNode "E1" "-" (parse_E1 $ subOp $ parse_T $ nextToken e)
        _   -> makeNodeWithChild "E1" "e" e

-- <T’> ::= * <F> <T’> | / <F> <T’> | e
parse_T1 :: Env -> Env
parse_T1 e = 
    let token = head $ tokens e
        op = v $ token
    in case op of
        "*" -> makeTernaryNode "T1" "*" (parse_T1 $ mulOp $ parse_F $ nextToken e)
        "/" -> makeTernaryNode "T1" "/" (parse_T1 $ divOp $ parse_F $ nextToken e)
        _   -> makeNodeWithChild "T1" "e" e

-- <F> ::= <number> | <var> | ( <E> ) | - <F>
parse_F :: Env -> Env
parse_F e =
    let token = head $ tokens e
        tokType = t $ token
        value = v $ token
    in case tokType of
        NumberToken     -> makeNodeWithChild "F" value (nextToken $ pushOp e token)
        BracketToken    -> makeNodeFBracket $ nextToken $ parse_E $ nextToken e
        _               -> error "unexpected token"



parse :: [Token] -> Env
parse tokenList = parse_E e
    where e = Env { tokens = tokenList
                  , stack = []
                  , nodes = [] }


printDigraph :: [Node] -> String
printDigraph ast = graphvizHeader ++ nodeList ++ edgeList ++ graphvizEnder
    where graphvizHeader = "digraph { dummy [label = \"\", shape = none] \n"
          graphvizEnder = "}"
          nodeList = (getNodeNames ast) ++ "\n"
          edgeList = (getEdgeList ast) ++ "\n"


mydfs graph visited [] = reverse visited
mydfs graph visited (x:xs) | elem x visited = mydfs graph visited xs
                           | otherwise = mydfs graph (x:visited) ((graph !! x) ++ xs)


dfs :: [Node] -> [Node] -> [Node]
dfs visited nodes =
    if null $ nodes
    then reverse visited
    else let curr = head nodes
             adjacent = childs curr
         in if curr `elem` visited
            then dfs visited (tail nodes)
            else dfs (curr:visited) (nodes ++ adjacent)


nodeToDigraphVertex node =
    "  " ++ show(nodeId node) ++ 
    " [label = \"" ++ (val node) ++ "\"" ++
    " shape = circle" ++
    " id = \"" ++ show(nodeId node) ++ "\"]"

getNodeNames ast = unlines names
    where names = map nodeToDigraphVertex dfsNodes
          dfsNodes = dfs [] ast 

nodeToDigraphEdge nodeFrom nodeTo =
    "  " ++ show(nodeId nodeFrom) ++ " -> " ++ show(nodeId nodeTo)

edgeHelper node childNodes =
    if null childNodes
    then []
    else let edge = nodeToDigraphEdge node (head childNodes)
         in [edge] ++ edgeHelper node (tail childNodes)

getEdges node = unwords edges
    where edges = edgeHelper node (childs node)

getEdgeList ast = unlines edges
    where edges = map getEdges dfsNodes
          dfsNodes = dfs [] ast


-- run Parser after Lexer: 
-- - make sure Lexer's filename is lexer.hs,
-- - comment Lexer's `main`
-- - do `runhaskell parser.hs`
main = do
    putStrLn ">>> scanning"
    -- let p2 = "(5 - 1) * (2 + 1) "
    -- let p2 = "2 * 5 + 3 * 4 + 4 * 6 "
    -- let p2 = "1 + 2 "
    let p2 = "1 + (2 + 3) * 4 - 5 * 4 - 10 + 5 "
    let tokens = scan p2
    mapM_ print tokens

    putStrLn "\n>>> parsing"
    let res = parse tokens

    putStrLn "\n>>> result"
    print $ stack res

    putStrLn "\n>>> AST"
    let ast = nodes res
    print ast

    putStrLn "\n>>> Graphviz"
    putStrLn $ printDigraph ast


    -- print ">>> DFS"
    -- let vis = dfs [] ast
    -- mapM_ print vis

    --putStrLn "\n>>> edges to root vertex childs:"
    --let edges = getEdges $ head ast
    --print edges


    
